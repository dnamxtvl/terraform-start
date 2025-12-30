variable "vpc" {
  type = any
}

variable "sg" {
  type = any
}

variable "ecr_nginx_url" {
  type = string
}

variable "ecr_php_fpm_url" {
  type = string
}

variable "iam_execution_role_arn" {
  type = string
}

variable "iam_task_role_arn" {
  type = string
}

variable "alb_target_group_arn" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "container_nginx_port" {
  type    = number
  default = 80
}

variable "container_fpm_port" {
  type    = number
  default = 9000
}

variable "desired_count" {
  type    = number
  default = 1
}
