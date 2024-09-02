variable "repository_name" {
  description = "the name of the repository"
  type        = string
}

variable "domain_name" {
  description = "the domain of the website, with the TLD last, e.g.  cat.mammal.animal.com"
  type        = string
  default     = "wlpr.dev"
}

variable "bucket_name" {
  description = "the name of the s3 bucket, with the TLD last, e.g.  cat.mammal.animal.com"
  type        = string
  default     = "wlpr.dev"
}


variable "s3_origin_id" {
  description = "A random ID that apparently can be anything as long as its unique and we're consistent."
  type        = string
  default     = "s3-wlpr-id"
}

variable "acm_certificate_arn" {
  description = "ARN of ACM Certificate"
  type        = string
}

variable "origin_response_lambda_qualified_arn" {
  description = "The qualified ARN for the Cloudfront lambda@edge origin response function"
}

variable "viewer_request_cloudfront_arn" {
  description = "The ARN for the Cloudfront viewer-request function"
}