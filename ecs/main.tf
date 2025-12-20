resource "aws_ecs_cluster" "ecs_cluster" {
  name = "quiz-ecs-cluster"
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "quiz-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = var.iam_execution_role_arn
  task_role_arn            = var.iam_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "nginx-container"
      image     = "${var.ecr_nginx_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_nginx_port
          hostPort      = var.container_nginx_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/healthcheck || exit 1"]
        interval    = 30
        timeout     = 5
        startPeriod = 10
        retries     = 3
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/quiz-task-family"
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "php-fpm-container"
      image     = "${var.ecr_php_fpm_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_fpm_port
          hostPort      = var.container_fpm_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/quiz-task-family"
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  name                 = "quiz-ecs-service"
  cluster              = aws_ecs_cluster.ecs_cluster.id
  task_definition      = aws_ecs_task_definition.task_definition.arn
  launch_type          = "FARGATE"
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets          = [for subnet in var.vpc.private_subnets_ecs : subnet.id]
    security_groups  = [var.sg.web]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "nginx-container"
    container_port   = var.container_nginx_port
  }

  depends_on = [var.alb_listener_arn]
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "dev_to_memory" {
  name               = "dev-to-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 85
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "dev_to_cpu" {
  name               = "dev-to-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 85
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Data source for region
data "aws_region" "current" {}
