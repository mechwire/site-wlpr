output "s3_bucket_arn" {
  description = "The ARN for the bucket that holds the static assets"
  value       = aws_s3_bucket.website_bucket.arn
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the Cloudfront instance"
  value       = aws_cloudfront_distribution.cdn_static_site.arn
}
