# ---------------------------------------------------------------------------
# Task Execution Role
# Used by the ECS agent to:
#   - Pull container images from ECR
#   - Write logs to CloudWatch
# ---------------------------------------------------------------------------
resource "aws_iam_role" "task_execution" {
  name = "${var.project}-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# Task Role
# Used by your application code at runtime.
# Currently empty — add inline policies here as your app needs AWS access
# (e.g. S3, DynamoDB, SQS, Secrets Manager).
# ---------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name = "${var.project}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
