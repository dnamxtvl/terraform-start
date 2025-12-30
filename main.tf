terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.24.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.6.0"
    }
  }
}

provider "aws" {
  region  = "ap-southeast-1"
  profile = "terraform-start"
}

module "vpc" {
  source = "./vpc"

  vpc_cidr_block             = "10.0.0.0/16"
  public_subnet              = ["10.0.4.0/24", "10.0.5.0/24"]
  private_subnet_ecs         = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_rds         = ["10.0.7.0/24", "10.0.8.0/24"]
  private_subnet_elasticache = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zone          = ["ap-southeast-1a", "ap-southeast-1b"]
}

module "sg" {
  source = "./sg"

  vpc = module.vpc
  sg  = null
}

module "route53" {
  source = "./route53"

  domain_name = var.domain_name
}

module "alb" {
  source = "./alb"

  vpc                    = module.vpc
  sg                     = module.sg.sg_system
  container_nginx_port   = 80
  lb_acm_certificate_arn = module.route53.lb_acm_certificate_arn
  domain_name            = var.domain_name
}

module "rds" {
  source = "./rds"

  vpc         = module.vpc
  sg          = module.sg.sg_system
  db_username = var.db_username
  db_password = var.db_password
}

module "elasticache" {
  source = "./elasticCache"

  elasticache_subnet_group_name = module.vpc.elasticache_subnet_group_name
  sg                            = module.sg.sg_system
}

module "s3" {
  source = "./s3"

  bucket_name         = "quiz-app-${data.aws_caller_identity.current.account_id}"
  enable_versioning   = true
  enable_encryption   = true
  block_public_access = false
  enable_logging      = false

  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::quiz-app-${data.aws_caller_identity.current.account_id}/*"
      },
    ]
  })

  tags = {
    Project = "quiz-app"
    Env     = "production"
  }
}

module "iam" {
  source = "./iam"
}

module "ecr" {
  source = "./ecr"
}

module "ec2" {
  source = "./ec2"

  vpc                        = module.vpc
  ami_id                     = var.baston_ami
  security_group_baston_name = module.sg.sg_system.baston.id
  key_name                   = var.bastion_key_name
}

module "lambda" {
  source = "./lambda"

  lambda_role_arn             = module.iam.lambda_exec_role_arn
  google_chat_general_webhook = var.google_chat_general_webhook
  google_chat_error_webhook   = var.google_chat_error_webhook
}

module "ecs" {
  source = "./ecs"

  vpc                    = module.vpc
  sg                     = module.sg.sg_system
  ecr_nginx_url          = module.ecr.repository_nginx_url
  ecr_php_fpm_url        = module.ecr.repository_php_fpm_url
  iam_execution_role_arn = module.iam.ecsTaskExecutionRoleQuiz_arn
  iam_task_role_arn      = module.iam.ecsTaskRoleQuiz_arn
  alb_target_group_arn   = module.alb.target_group_arn
  alb_listener_arn       = module.alb.listener_arn
  container_nginx_port   = 80
  container_fpm_port     = 9000
  desired_count          = var.desired_count
}

module "cloudwatch" {
  source = "./cloudwatch"

  lambda_arn     = module.lambda.lambda_arn
  log_group_name = "/ecs/quiz-task-family"
  filter_pattern = ""
}

module "amplify" {
  source = "./amplify"

  amplify_iam_role_arn = module.iam.amplify_role_arn
  domain_name          = var.domain_name

  # Firebase credentials
  firebase_api_key             = var.firebase_api_key
  firebase_app_id              = var.firebase_app_id
  firebase_auth_domain         = var.firebase_auth_domain
  firebase_measurement_id      = var.firebase_measurement_id
  firebase_messaging_sender_id = var.firebase_messaging_sender_id
  firebase_project_id          = var.firebase_project_id
  firebase_storage_bucket      = var.firebase_storage_bucket
  firebase_vapid_key           = var.firebase_vapid_key

  # Google credentials
  google_client_id = var.google_client_id

  # App configuration
  app_url        = var.app_url
  backend_url    = var.backend_url
  backend_host   = var.backend_host
  reverb_key     = var.reverb_key
  repository_url = var.repository_url
  fe_domain      = var.fe_domain
}

module "cloudfront" {
  source = "./cloudfront"

  domain_name                    = var.domain_name
  s3_bucket_regional_domain_name = module.s3.bucket_regional_domain_name
  s3_bucket_id                   = module.s3.bucket_id
  route53_zone_id                = module.route53.zone_id
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}
