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

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = {
    github     = true,
    repository = var.repository_name
  }
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
    cloudfront_default_certificate = true
  }

  # Optional
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  tags = {
    github     = true,
    repository = var.repository_name
  }
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

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = data.aws_iam_policy_document.website.json
}
