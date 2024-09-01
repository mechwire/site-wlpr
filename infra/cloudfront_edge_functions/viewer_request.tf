resource "aws_cloudfront_function" "request" {
  name    = "${var.repository_name}_ViewerRequestValidator"
  runtime = "cloudfront-js-2.0"
  comment = "Resolves URL to index.html if nothing more specific exists as well as rate limiting requests to prevent crawling"
  publish = true
  code    = file("${path.cwd}/cloudfront_functions/request_validator.js")

  key_value_store_associations = [
    aws_cloudfront_key_value_store.lambda_honeypot.arn,
  ]
}