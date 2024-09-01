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

module "static_asset_hosting" {
  source = "./cloudfront_s3"

  repository_name = var.repository_name
  bucket_name     = var.bucket_name
  domain_name     = var.domain_name
  s3_origin_id    = var.s3_origin_id
}

# Custom Domain

module "dns_routing_to_static_assets" {
  source = "./dns_for_site"

  repository_name            = var.repository_name
  domain_name                = var.domain_name
  cloudfront_distribution_id = var.cloudfront_distribution_arn
}
