resource "aws_amplify_app" "quizz_app" {
  name       = "quizz-app"
  repository = var.repository_url

  enable_branch_auto_build = true
  enable_basic_auth        = false

  iam_service_role_arn = var.amplify_iam_role_arn

  # Enable access logs
  enable_auto_branch_creation = false
  enable_branch_auto_deletion = false

  # The default build_spec added by the Amplify Console for Nuxt 3.
  build_spec = <<-EOT
    version: 1
    frontend:
    phases:
        preBuild:
        commands:
            - nvm use 20
            - node --version
            - npm install
        build:
        commands:
            - npm ci
            - npm run build
            - mkdir -p .amplify-hosting
            - cp deploy-manifest.json .amplify-hosting/deploy-manifest.json
    artifacts:
        baseDirectory: .output/public
        files:
      - "**/*"
  EOT

  # The default rewrites and redirects added by the Amplify Console.
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }

  environment_variables = {
    BACKEND_HOST                = var.backend_host
    BACKEND_URL                 = var.backend_url
    FIREBASE_API_KEY            = var.firebase_api_key
    FIREBASE_APP_ID             = var.firebase_app_id
    FIREBASE_AUTH_DOMAIN        = var.firebase_auth_domain
    FIREBASE_MEASUREMENT_ID      = var.firebase_measurement_id
    FIREBASE_MESSAGING_SENDER_ID = var.firebase_messaging_sender_id
    FIREBASE_PROJECT_ID         = var.firebase_project_id
    FIREBASE_STORAGE_BUCKET     = var.firebase_storage_bucket
    FIREBASE_VAPID_KEY          = var.firebase_vapid_key
    GOOGLE_CLIENT_ID            = var.google_client_id
    FRONTEND_URL                = var.app_url
    PORT                        = 8088
    REVERB_KEY                  = var.reverb_key
  }

  # Custom headers for security
  custom_headers = <<-EOT
    X-Frame-Options: DENY
    X-Content-Type-Options: nosniff
    X-XSS-Protection: 1; mode=block
    Referrer-Policy: strict-origin-when-cross-origin
  EOT
}

resource "aws_amplify_branch" "master" {
  app_id      = aws_amplify_app.quizz_app.id
  branch_name = "master"
  display_name = "master"
  description = "Master branch"
  enable_auto_build = true
  framework   = "nuxt"

  enable_notification = false
  enable_pull_request_preview = false

  environment_variables = {
    BACKEND_HOST                = var.backend_host
    BACKEND_URL                 = var.backend_url
    FIREBASE_API_KEY            = var.firebase_api_key
    FIREBASE_APP_ID             = var.firebase_app_id
    FIREBASE_AUTH_DOMAIN        = var.firebase_auth_domain
    FIREBASE_MEASUREMENT_ID      = var.firebase_measurement_id
    FIREBASE_MESSAGING_SENDER_ID = var.firebase_messaging_sender_id
    FIREBASE_PROJECT_ID         = var.firebase_project_id
    FIREBASE_STORAGE_BUCKET     = var.firebase_storage_bucket
    FIREBASE_VAPID_KEY          = var.firebase_vapid_key
    GOOGLE_CLIENT_ID            = var.google_client_id
    FRONTEND_URL                = var.app_url
    PORT                        = 8088
    REVERB_KEY                  = var.reverb_key
  }
}
# Data source for Route53 zone
data "aws_route53_zone" "selected_zone" {
  name         = var.domain_name
  private_zone = false
}

# Custom domain for Amplify app
resource "aws_amplify_domain_association" "main" {
  app_id      = aws_amplify_app.quizz_app.id
  domain_name = var.domain_name  # Root domain: 5qsoft.com

  # quiz subdomain (quiz.5qsoft.com)
  sub_domain {
    branch_name = aws_amplify_branch.master.branch_name
    prefix      = "quiz"
  }

  wait_for_verification = true
}

# Route53 record for certificate verification
resource "aws_route53_record" "amplify_cert_verification" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = split(" ", aws_amplify_domain_association.main.certificate_settings[0].certificate_verification_dns_record)[0]
  type    = "CNAME"
  ttl     = 60

  records = [
    split(" ", aws_amplify_domain_association.main.certificate_settings[0].certificate_verification_dns_record)[2]
  ]

  allow_overwrite = true

  depends_on = [aws_amplify_domain_association.main]
}

# Route53 CNAME record for quiz.5qsoft.com to Amplify CloudFront
resource "aws_route53_record" "quiz_amplify" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = "quiz.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300

  # Parse dns_record: "quiz CNAME dbwjtoa0eebni.cloudfront.net"
  records = [
    for subdomain in aws_amplify_domain_association.main.sub_domain :
    split(" ", subdomain.dns_record)[2]  # Get the CloudFront domain
    if subdomain.prefix == "quiz"
  ]

  allow_overwrite = true

  depends_on = [aws_amplify_domain_association.main]
}
