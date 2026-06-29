variable "region" {
  description = "AWS region"
  default     = "eu-north-1"
}

variable "project" {
  description = "Project name prefix for all resources"
  default     = "ecs-aiops"
}

variable "notification_email" {
  description = "Email address for DevOps Guru SNS notifications"
  default     = "<your_email_address@example.com>"
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MB"
  default     = 512
}
