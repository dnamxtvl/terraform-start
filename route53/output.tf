# Outputs for the Route53 module for load balancer

output "lb_acm_certificate_arn" {
  value       = aws_acm_certificate_validation.cert_validation.certificate_arn
  description = "ARN of the ACM certificate for load balancer"
}

output "zone_id" {
  value       = data.aws_route53_zone.selected_zone.zone_id
  description = "Zone ID of the Route53 zone"
}