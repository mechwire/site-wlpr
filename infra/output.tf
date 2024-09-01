output "website_s3_bucket_arn" {
  description = "The ARN for the bucket that holds the static assets"
  value       = static_asset_hosting.s3_bucket_arn
}

output "cloudfront_distribution_id" {
  description = "The ARN of the Cloudfront instance"
  value       = static_asset_hosting.cloudfront_distribution_arn
}
