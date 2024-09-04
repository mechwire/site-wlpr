terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.48.0"
      configuration_aliases = [aws, aws.us_east_1]
    }
  }
}


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
