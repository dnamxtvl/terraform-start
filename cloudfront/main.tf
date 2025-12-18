# For cloudfront, the acm has to be created in us-east-1 or it will not work
provider "aws" {
  region  = "us-east-1"
  alias   = "us-east-1"
  profile = "terraform-start"
}

# Data source for Route53 zone
data "aws_route53_zone" "selected_zone" {
  name         = var.domain_name
  private_zone = false
}

# ACM Certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "cloudfront_cert" {
  provider = aws.us-east-1

  domain_name               = "quiz-cdn.${var.domain_name}"
  subject_alternative_names = ["*.quiz-cdn.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 records for ACM certificate validation
resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "cloudfront_cert" {
  provider = aws.us-east-1

  certificate_arn = aws_acm_certificate.cloudfront_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# CloudFront Distribution using terraform-aws-modules
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.0.2"

  comment             = "Quiz App CDN"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_200"
  retain_on_delete    = false
  wait_for_deployment = true

  # Custom domain with SSL
  aliases = ["quiz-cdn.${var.domain_name}"]

  viewer_certificate = {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront_cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  origin_access_control = {
    s3_oac = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  # Default cache behavior
  default_cache_behavior = {
    target_origin_id       = var.s3_bucket_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    use_forwarded_values = false

    # Use managed cache policy for better performance
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingOptimized
  }

  # S3 Origin (using custom origin config for HTTPS)
  origin = {
    "${var.s3_bucket_id}" = {
      domain_name = var.s3_bucket_regional_domain_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy  = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Custom error responses for SPA
  custom_error_response = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]

  tags = {
    Name    = "quiz-cdn"
    Project = "quiz-app"
    Env     = "production"
  }
}

# Route53 record for CloudFront (module doesn't create this automatically)
resource "aws_route53_record" "cloudfront_alias" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = "quiz-cdn.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.cloudfront.cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}