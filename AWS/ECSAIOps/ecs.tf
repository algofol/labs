# ── Cluster ───────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = var.project

  # Container Insights must be enabled — DevOps Guru uses these CloudWatch
  # metrics (MemoryUtilization, CPUUtilization, RunningTaskCount) to detect anomalies
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name              = var.project
    DevOpsGuruEnabled = "true"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE"]
}

# ── IAM: Task Execution Role ──────────────────────────────────────────────────
resource "aws_iam_role" "task_execution" {
  name = "${var.project}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
}

# ── Task Definition ───────────────────────────────────────────────────────────
# The image tag is set to "healthy" initially.
# To trigger the OOM anomaly, push a "defective" image and update this tag.
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:healthy"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = { DevOpsGuruEnabled = "true" }
}

# ── Service ───────────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = "${var.project}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  tags = { DevOpsGuruEnabled = "true" }
}
