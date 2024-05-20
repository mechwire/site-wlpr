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

// IAM alone is not enough to grant access to the contents of an s3 bucket, particularly for PutObject. We need a policy document to allow it.
data "aws_iam_policy_document" "website_bucket_objects" {
  statement {
    principals {
      type        = "AWS" // Overly permissive, because we're restricting it below
      identifiers = [data.aws_caller_identity.current.arn]
    }

    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = [aws_s3_bucket.website_bucket.arn]
  }
}

resource "aws_s3_bucket_policy" "website_bucket_objects" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tf_state_bucket_objects.json
}

resource "aws_cloudfront_distribution" "cdn_static_site" {
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = var.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
  }

  enabled = false

  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id = var.s3_origin_id
  }

  restrictions {
    geo_restrictions {
        locations = []
        restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Optional
  tags = {
    github     = true,
    repository = var.repository_name
  }
}


# Connect s3 to Cloudfront

data "aws_iam_policy_document" "website" {
  statement {
    sid = "CloudfrontToS3"
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
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}