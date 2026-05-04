variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name used for tagging all resources. Used in Cost Explorer to filter costs."
  type        = string
  default     = "dataarchpoc01"
}

