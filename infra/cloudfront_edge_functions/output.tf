output "origin_response_lambda_qualified_arn" {
  description = "The qualified ARN for the Cloudfront lambda@edge origin response function"
  value       = aws_lambda_function.lambda_honeypot.qualified_arn
}

output "viewer_request_cloudfront_arn" {
  description = "The ARN for the Cloudfront viewer-request function"
  value       = aws_cloudfront_function.request.arn
}