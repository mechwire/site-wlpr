output "route53_zone_id" {
  description = "the ID of the Route53 zone"
  value       = aws_route53_zone.zone.zone_id
}
