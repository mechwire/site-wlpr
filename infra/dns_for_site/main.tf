data "aws_caller_identity" "current" {}

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

// This exists in Porkbun, but we need to recreate them in AWS's NS.
module "dns_records" {
  source = "./dns_records"

  domain_name                = var.domain_name
  route53_zone_id            = aws_route53_zone.zone.id
  cloudfront_distribution_id = var.cloudfront_distribution_id

}
