variable "repository_name" {
  description = "the name of the repository"
  type        = string
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
