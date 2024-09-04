variable "repository_name" {
  description = "the name of the repository"
  type        = string
}

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
