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

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# Custom Domain

module "dns_routing_to_static_assets" {
  source = "./dns_for_site"

  repository_name = var.repository_name
  domain_name     = var.domain_name

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

module "domain_certificate" {
  source = "./domain_certificate"

  repository_name = var.repository_name
  domain_name     = var.domain_name
  route53_zone_id = module.dns_routing_to_static_assets.route53_zone_id


  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# Static Asset Hosting

module "edge_functions" {
  source = "./cloudfront_edge_functions"

  repository_name = var.repository_name

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}


module "static_asset_hosting" {
  source = "./cloudfront_s3"

  repository_name                      = var.repository_name
  bucket_name                          = var.bucket_name
  domain_name                          = var.domain_name
  s3_origin_id                         = var.s3_origin_id
  acm_certificate_arn                  = module.domain_certificate.acm_certificate_arn
  origin_response_lambda_qualified_arn = module.edge_functions.origin_response_lambda_qualified_arn
  viewer_request_cloudfront_arn        = module.edge_functions.viewer_request_cloudfront_arn

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}


// This exists in Porkbun, but we need to recreate them in AWS's NS.
module "dns_records" {
  source = "./dns_records"

  domain_name                = var.domain_name
  route53_zone_id            = module.dns_routing_to_static_assets.route53_zone_id
  cloudfront_distribution_id = module.static_asset_hosting.cloudfront_distribution_id

  providers = {
    aws = aws.us_east_1
  }
}
