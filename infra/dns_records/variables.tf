variable "domain_name" {
  description = "the domain name, with or without a subdomain"
  type        = string
  default     = "subdomain.domain.tld"
}

variable "route53_zone_id" {
  description = "the ID of the Route53 zone"
  type        = string
  default     = "Z1D633PJN98FT9"
}

variable "cloudfront_distribution_id" {
  description = "the ID of the Cloudfront distribution"
  type        = string
  default     = "EDFDVBD632BHDS5"
}
