module "alb_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "alb-sg"
  description = "Security group for ALB - allow HTTP and HTTPS from internet"
  vpc_id      = var.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "http-80-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "https-443-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "web_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "web-sg"
  description = "Security group for web ec2, ecs, allow traffic from ALB"
  vpc_id      = var.vpc.vpc_id
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
    },
    { 
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  # Allow all out bound traffic
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

# public security group for ec2 baston host, allow all ssh from internet
module "baston_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "quiz-baston-sg"
  description = "Security group for EC2 baston host, allow SSH from internet"
  vpc_id      = var.vpc.vpc_id
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  # Allow outbound to anywhere
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "db_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "db-sg"
  description = "Security group for RDS instance, allow traffic from ECS only"
  vpc_id      = var.vpc.vpc_id
  ingress_with_source_security_group_id = [
    {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      source_security_group_id = module.web_sg.security_group_id
    },
    {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      source_security_group_id = module.baston_sg.security_group_id
    }
  ]
  # Allow outbound to anywhere (for replication, backups, etc)
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "elasticache_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "elasticache-sg"
  description = "Security group for ElastiCache Redis, allow traffic from ECS only"
  vpc_id      = var.vpc.vpc_id
  ingress_with_source_security_group_id = [
    {
      from_port                = 6379
      to_port                  = 6379
      protocol                 = "tcp"
      source_security_group_id = module.web_sg.security_group_id
    },
    {
      from_port                = 6379
      to_port                  = 6379
      protocol                 = "tcp"
      source_security_group_id = module.baston_sg.security_group_id
    }
  ]
  # Allow outbound to anywhere
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
