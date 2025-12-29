resource "aws_db_instance" "database" {
  allocated_storage            = 20
  max_allocated_storage        = 100
  engine                       = "mysql"
  engine_version               = "8.0"
  instance_class               = "db.t3.micro"
  identifier                   = "terraform-db-instance"
  db_name                      = "quiz_producttion"
  username                     = var.db_username
  password                     = var.db_password
  db_subnet_group_name         = var.vpc.rds_subnet_group_name
  vpc_security_group_ids       = [var.sg.db]
  skip_final_snapshot          = true
  multi_az                     = true
  storage_encrypted            = true
  performance_insights_enabled = false // true fo config db.t3.medium
  //performance_insights_retention_period = 7
}
