terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.48.0"
    }
  }
}


data "aws_cloudfront_distribution" "site" {
  id = var.cloudfront_distribution_id
}

// IPv6 adoption is at 50%; to make our website available to everyone, we need to support v4 (A) and v6 (AAAA)
// https://www.google.com/intl/en/ipv6/statistics.html


resource "aws_route53_record" "apexv4" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.aws_cloudfront_distribution.site.domain_name
    zone_id                = data.aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apexv6" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = data.aws_cloudfront_distribution.site.domain_name
    zone_id                = data.aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}