# https://www.playingaws.com/posts/how-to-deploy-serverless-website-with-terraform/#v2-cloudfront-distribution--private-s3-bucket

terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.48.0"
    }
  }
}

provider "aws" {}

// Some resources need to exist in us-east-1, even if it's different from your typical region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = {
    github     = true,
    repository = var.repository_name
  }
}

# Custom Domain

resource "aws_route53_zone" "zone" {
  name = var.domain_name
}

data "aws_iam_policy_document" "dnssec" {

  // AWS really does not want you locked out.
  // "MalformedPolicyDocumentException: The new key policy will not allow you to update the key policy in the future."
  statement {
    sid = "Allow last-resort administration of the key"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "kms:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Allow administration of the key"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Allow Route 53 DNSSEC Service"
    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:route53:::hostedzone/*"]
    }

  }

  statement {
    sid = "Allow Route 53 DNSSEC Service to CreateGrant"
    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant"
    ]
    // https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
    // (Required) In a key policy, the value of the Resource element is "*", which means "this KMS key." The asterisk ("*") identifies the KMS key to which the key policy is attached.
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = [true]
    }
  }
}


// https://www.cloudflare.com/dns/dnssec/how-dnssec-works/
// DNSSEC associates a cryptographic signature to your domain's DNS records to ensure they were not tampered with during the address resolution flow
resource "aws_kms_key" "dnssec" {
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 7
  key_usage                = "SIGN_VERIFY"
  policy                   = data.aws_iam_policy_document.dnssec.json

  provider = aws.us_east_1 // Certificates for Cloudfront use need to exist in us-east-1
}

resource "aws_route53_key_signing_key" "dnssec" {
  hosted_zone_id             = aws_route53_zone.zone.id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                       = "${var.domain_name}_dnssec"
}

resource "aws_route53_hosted_zone_dnssec" "dnssec" {
  depends_on = [
    aws_route53_key_signing_key.dnssec
  ]
  hosted_zone_id = aws_route53_key_signing_key.dnssec.hosted_zone_id
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  // When the certificate needs renewing, it will recreate it before deleting the old one
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    github     = true,
    repository = var.repository_name
  }

  // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html#https-requirements-aws-region
  provider = aws.us_east_1 // Certificates for Cloudfront use need to exist in us-east-1
}

// Once, we should manually repoint the Porkbun registration to use AWS's nameservers. There's no official Terraform support for Porkbun.

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 604800 // We opt for a week, since there shouldn't be much change
  type            = each.value.type
  zone_id         = aws_route53_zone.zone.zone_id

  // Certificates for Cloudfront use need to exist in us-east-1
  // This record is for the certificate validation process
  provider = aws.us_east_1
}

// We should wait, so we can attach this on our Cloudfront Distribution resource
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  provider = aws.us_east_1 // Certificates for Cloudfront use need to exist in us-east-1
}


/* WAF

https://systemweakness.com/aws-waf-with-terraform-1dafa305c4a1
https://badshah.io/things-i-wish-i-knew-aws-waf-bot-control/

I was going to use WAF, but a few issues came up:
   * I had a hard time setting up bot protection. Out of the box, it would either count or do nothing; it wasn't clear to me how to actually block. In trying to figure that out, I discovered more, like...
   * Bot protection was relatively cheap. But ACLs for WAF (which enable Bot Protection) were a relatively high fixed cost of $5/mo + $1/rule.
   * Cloudfront's Free Tier is 10M per month. After that, the most expensive regions are $0.016/10k. So to doing things the right way:
       * Flat, Monthly ACL Cost: ACL + 1 Rule for Rate Limiting + 1 Rule for Bot protection = $7/mo.
       * Cloudfront Traffic Needed to get to $7: roughly 10M/mo.
           * (Free Tier Requests) + (Flat, Monthly ACL Cost)/(per 10k Cost of most expensive geography, South America)*(10,000) or (10M + $7/($0.016)*10k)
Instead, the cheapest solution here is likely alerting.
*/

# Cloudfront

resource "aws_cloudfront_function" "request" {
  name    = "RequestValidator"
  runtime = "cloudfront-js-2.0"
  comment = "Resolves URL to index.html if nothing more specific exists as well as rate limiting requests to prevent crawling"
  publish = true
  code    = file("${path.module}/cloudfront_functions/request_validator.js")
}

resource "aws_cloudfront_origin_access_control" "cdn_static_site" {
  name                              = var.bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn_static_site" {
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.request.arn
    }

    # Optional
    min_ttl = 3600
  }

  enabled = true

  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = var.s3_origin_id

    # Optional
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn_static_site.id
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only" // recommended setting, supported by most
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Optional
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  tags = {
    github     = true,
    repository = var.repository_name
  }

  provider = aws.us_east_1 // Certificates for Cloudfront use need to exist in us-east-1
}

// Set the s3 Bucket Policy

data "aws_iam_policy_document" "website" {
  // IAM alone is not enough to grant access to the contents of an s3 bucket, particularly for PutObject. We need a policy document to allow it.
  statement {
    sid = "WebsiteBucketObjects"
    principals {
      type        = "AWS" // Overly permissive, because we're restricting it below
      identifiers = [data.aws_caller_identity.current.arn]
    }

    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.website_bucket.arn}/*"]
  }

  // Connect s3 to Cloudfront
  statement {
    sid       = "CloudfrontToS3"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.cdn_static_site.arn]
    }
  }
}

// This exist in Porkbun, but we need to recreate them in AWS's NS.

// IPv6 adoption is at 50%; to make our website available to everyone, we need to support v4 (A) and v6 (AAAA)
// https://www.google.com/intl/en/ipv6/statistics.html

resource "aws_route53_record" "apexv4" {
  zone_id = aws_route53_zone.zone.id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apexv6" {
  zone_id = aws_route53_zone.zone.id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = data.aws_iam_policy_document.website.json
}
