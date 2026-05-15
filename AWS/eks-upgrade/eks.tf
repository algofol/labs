# ──────────────────────────────────────────────
# Cluster security group (allows node-to-control-plane traffic)
# ──────────────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster control-plane security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow nodes to reach the API server"
}

# ──────────────────────────────────────────────
# Node security group
# ──────────────────────────────────────────────
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "EKS worker nodes security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all traffic between nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Allow control plane to communicate with nodes"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-nodes-sg" })
}

# ──────────────────────────────────────────────
# EKS Cluster
# ──────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Enable control-plane logging for the upgrade audit trail
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # IMPORTANT: during version upgrades, Terraform will update this field.
  # The cluster upgrade happens in-place — no node group changes yet.
  lifecycle {
    ignore_changes = [
      # Prevent Terraform from fighting with AWS-managed add-on versions
      # after an upgrade. Managed separately in addons.tf.
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = var.tags
}

# ──────────────────────────────────────────────
# EKS Managed Node Group — "system" (general purpose)
# ──────────────────────────────────────────────
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-system"
  node_role_arn   = aws_iam_role.eks_node.arn

  # Place nodes in private subnets only
  subnet_ids = aws_subnet.private[*].id

  # Kubernetes version — must match (or be one minor version behind) the cluster.
  # When upgrading the cluster first change cluster_version, apply, then update
  # this to match so nodes are rolling-replaced with the new AMI.
  version        = var.node_group_version
  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.node_instance_type]
  disk_size      = var.node_disk_size

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Zero-downtime rolling update strategy:
  # - MAX_UNAVAILABLE = 1 keeps all other nodes healthy while one is replaced.
  update_config {
    max_unavailable = 1
  }

  # Allow force-update (drain + terminate) when AMI needs replacing
  force_update_version = false

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
  ]

  tags = merge(var.tags, { Name = "${var.cluster_name}-system-nodes" })

  lifecycle {
    create_before_destroy = true
  }
}
