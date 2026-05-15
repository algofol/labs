# Core EKS add-ons
#
# UPGRADE NOTES
# ─────────────
# When upgrading the cluster version, update the add-on addon_version values
# to the versions compatible with the new Kubernetes version.
# You can list available versions with:
#   aws eks describe-addon-versions --addon-name <name> --kubernetes-version <ver>
#
# Compatible versions for each stage:
# ┌──────────────────────────┬──────────────────────┬──────────────────────┬──────────────────────┐
# │ Add-on                   │ k8s 1.33             │ k8s 1.34             │ k8s 1.35             │
# ├──────────────────────────┼──────────────────────┼──────────────────────┼──────────────────────┤
# │ vpc-cni                  │ v1.19.0-eksbuild.1   │ v1.21.1-eksbuild.8   │ v1.21.1-eksbuild.8   │
# │ coredns                  │ v1.11.4-eksbuild.2   │ v1.13.2-eksbuild.7   │ v1.13.2-eksbuild.7   │
# │ kube-proxy               │ v1.33.0-eksbuild.2   │ v1.34.6-eksbuild.5   │ v1.34.6-eksbuild.5   │
# │ eks-pod-identity-agent   │ v1.3.4-eksbuild.1    │ v1.3.10-eksbuild.3   │ v1.3.10-eksbuild.3   │
# └──────────────────────────┴──────────────────────┴──────────────────────┴──────────────────────┘
# Above information was retrieved with:
# k_vers='1.34'; for addon in vpc-cni coredns kube-proxy eks-pod-identity-agent; do   echo "=== $addon ===";   aws eks describe-addon-versions --addon-name $addon --kubernetes-version $k_vers     --query 'addons[0].addonVersions[0].addonVersion' --output text; done

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.21.1-eksbuild.8"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null   # uses node role via IRSA if needed

  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = "v1.13.2-eksbuild.7"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]

  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.34.6-eksbuild.5"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = "v1.3.10-eksbuild.3"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]

  tags = var.tags
}
