# Outputs from terraform-aws-modules/cloudfront/aws
output "cloudfront_distribution_id" {
  value       = module.cloudfront.cloudfront_distribution_id
  description = "CloudFront distribution ID"
}

output "cloudfront_distribution_arn" {
  value       = module.cloudfront.cloudfront_distribution_arn
  description = "CloudFront distribution ARN"
}

output "cloudfront_domain_name" {
  value       = module.cloudfront.cloudfront_distribution_domain_name
  description = "CloudFront distribution domain name"
}

output "cloudfront_hosted_zone_id" {
  value       = module.cloudfront.cloudfront_distribution_hosted_zone_id
  description = "CloudFront distribution hosted zone ID"
}

output "cloudfront_certificate_arn" {
  value       = aws_acm_certificate_validation.cloudfront_cert.certificate_arn
  description = "ACM certificate ARN for CloudFront"
}

