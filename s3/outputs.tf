output "bucket_id" {
  value       = module.s3_bucket.s3_bucket_id
  description = "The name of the S3 bucket"
}

output "bucket_arn" {
  value       = module.s3_bucket.s3_bucket_arn
  description = "The ARN of the S3 bucket"
}

output "bucket_region" {
  value       = module.s3_bucket.s3_bucket_region
  description = "The AWS region this bucket resides in"
}

output "bucket_domain_name" {
  value       = module.s3_bucket.s3_bucket_bucket_domain_name
  description = "The bucket domain name"
}

output "bucket_regional_domain_name" {
  value       = module.s3_bucket.s3_bucket_bucket_regional_domain_name
  description = "The bucket region-specific domain name"
}
