// This allows us to serve data from private blob storage through a CDN
//     * s3 is blob storage
//     * Cloudfront is a CDN that accomplishes caching and hosting

// Many resources need to exist in us-east-1, even if it's different from your typical region
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

// s3 Bucket
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = {
    github     = true,
    repository = var.repository_name
  }
}

// Cloudfront Distribution

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

    lambda_function_association {
      event_type   = "origin-response"
      lambda_arn   = var.origin_response_lambda_qualified_arn
      include_body = false
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = var.viewer_request_cloudfront_arn
    }

    # Optional
    min_ttl = 3600

    default_ttl = 3600
    max_ttl     = 86400
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
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only" // recommended setting, supported by most
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Optional
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  custom_error_response {
    error_caching_min_ttl = 3600
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error.html"
  }
  
  custom_error_response {
    error_caching_min_ttl = 3600
    error_code            = 500
    response_code         = 500
    response_page_path    = "/error.html"
  }

  tags = {
    github     = true,
    repository = var.repository_name
  }

  provider = aws.us_east_1 // Certificates for Cloudfront use need to exist in us-east-1
}

// Set the s3 Bucket Policy, connecting s3 and Cloudfront

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
