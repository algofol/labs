output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_version" {
  description = "Current Kubernetes version of the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA data for kubeconfig"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Run this to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "node_group_status" {
  description = "Managed node group status"
  value       = aws_eks_node_group.system.status
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (worker nodes)"
  value       = aws_subnet.private[*].id
}
