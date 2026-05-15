# ---------------------------------------------------------------------------
# CloudWatch Log Group — container stdout/stderr land here
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
}

# ---------------------------------------------------------------------------
# ECS Cluster
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ---------------------------------------------------------------------------
# Task Definition
# Describes WHAT to run (image, CPU, memory, ports, logging).
# Every change creates a new revision — the service decides which to use.
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-app"
  network_mode             = "awsvpc"   # required for Fargate; each task gets its own ENI
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true

      # Writes a version page before starting nginx.
      # Change app_version in variables.tf to simulate a new deployment.
      command = [
        "/bin/sh", "-c",
        "echo '<h1>${var.app_version}</h1>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
      ]

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# ECS Service
# Keeps `desired_count` tasks running and registers them behind the ALB.
# Uses the default ECS rolling deployment controller (no CodeDeploy yet).
# ---------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name            = "${var.project}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Rolling update settings:
  #   - minimum_healthy_percent = 100 → never kill old tasks before new ones are healthy
  #   - maximum_percent         = 200 → allows double capacity during a rollout
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  # Ignore task_definition changes made outside Terraform (e.g. by CodeDeploy later)
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http]
}
