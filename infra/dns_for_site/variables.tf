variable "repository_name" {
  description = "the name of the repository"
  type        = string
}

variable "domain_name" {
  description = "the domain of the website, with the TLD last, e.g.  cat.mammal.animal.com"
  type        = string
  default     = "wlpr.dev"
}
