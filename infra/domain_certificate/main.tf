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
  zone_id         = var.route53_zone_id

  // Certificates for Cloudfront use need to exist in us-east-1
  // This record is for the certificate validation process
  provider = aws.us_east_1
}

// For this resource, you need to look at the Route53 records created and copy over the nameservers over. Otherwise, it will go on for a long time.
// We should wait, so we can attach this on our Cloudfront Distribution resource
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  provider = aws.us_east_1 // Certificates for Cloudfront use need to exist in us-east-1
}