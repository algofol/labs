variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "project" {
  description = "Project name — used as a prefix on all resources"
  type        = string
  default     = "ecs-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_image" {
  description = "Docker image to run"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 2
}

variable "task_cpu" {
  description = "vCPU units for the task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory in MiB for the task"
  type        = number
  default     = 512
}

variable "app_version" {
  description = "Version label shown on the app page — change this to simulate a new deployment"
  type        = string
  default     = "v2"
}
