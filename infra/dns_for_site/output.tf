output "route53_zone_id" {
  description = "the ID of the Route53 zone"
  value       = aws_route53_zone.zone.zone_id
}

output "acm_certificate_arn" {
  description = "ACM Certificate arn"
  value       = aws_acm_certificate.cert.arn
}