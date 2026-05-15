variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-upgrade-lab"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (upgrade control plane first)"
  type        = string
  default     = "1.33"
}

variable "node_group_version" {
  description = "Kubernetes version for the managed node group (upgrade node group later)"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_instance_type" {
  description = "EC2 instance type for managed node group workers"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Disk size in GiB for each worker node"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "eks-upgrade-lab"
    ManagedBy   = "terraform"
  }
}
