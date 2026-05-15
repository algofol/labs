# EKS Zero-Downtime Upgrade Lab

End-to-end lab that provisions an EKS 1.33 cluster on EC2 managed nodes in **eu-north-1**,
deploys two sample applications with zero-downtime patterns, and walks you through a
**1.33 → 1.34 → 1.35** in-place upgrade path using Terraform.

## Architecture

```
eu-north-1
├── VPC  10.0.0.0/16
│   ├── Public subnets  ×3 AZs  (NAT Gateways, future LBs)
│   └── Private subnets ×3 AZs  (Worker nodes)
│
├── EKS Control Plane  (v1.33)
│   └── Managed Node Group  2×t3.medium  (RollingUpdate, max_unavailable=1)
│
└── Add-ons:  vpc-cni · coredns · kube-proxy · eks-pod-identity-agent
```

## Zero-downtime patterns used in the sample apps

| Pattern | Where |
|---|---|
| `maxUnavailable: 0` + `maxSurge: 1` rolling update | Both Deployments |
| `PodDisruptionBudget` (`minAvailable: 2`) | Both apps |
| `topologySpreadConstraints` across nodes and AZs | Both Deployments |
| `preStop` sleep hook (drains in-flight connections) | Both containers |
| Readiness probe (traffic only flows to ready pods) | Both containers |

---

## 1. Initial deployment — EKS 1.33

```bash
cd eks-upgrade/

terraform init
terraform apply
```

Configure kubectl:

```bash
aws eks update-kubeconfig --region eu-north-1 --name eks-upgrade-lab
kubectl get nodes
```

Deploy the sample apps:

```bash
kubectl apply -f apps/web-app.yaml
kubectl apply -f apps/api-app.yaml
kubectl get pods -o wide
```

---

## 2. Upgrade path: 1.33 → 1.34 → 1.35

> EKS only supports **one minor version at a time**.  
> You must go 1.33 → 1.34 → 1.35 — you cannot skip a version.

### Step 1 — Upgrade control plane to 1.34

`cluster_version` and `node_group_version` are decoupled, so you move the control plane
first and leave the nodes on 1.33 until you are ready.

In `variables.tf`, change **only** `cluster_version`:

```hcl
cluster_version    = "1.34"   # was 1.33
node_group_version = "1.33"   # unchanged — nodes stay on 1.33
```

Also update the affected add-ons in `addons.tf`:

```hcl
# kube-proxy must match the control-plane version
addon_version = "v1.34.0-eksbuild.2"   # kube-proxy
addon_version = "v1.11.4-eksbuild.3"   # coredns (check latest for 1.34)
```

Apply — **only the control plane is upgraded**, nodes are untouched:

```bash
terraform apply
```

Verify:

```bash
kubectl version --short
# Server: v1.34.x
for i in vpc-cni coredns kube-proxy eks-pod-identity-agent; do \
  aws eks describe-addon --cluster-name eks-upgrade-lab --region eu-north-1 \
  --addon-name $i --query '[addon.addonName, addon.addonVersion]' --output text; done
# Add-on versions as expected in addons.tf
kubectl get nodes
# Nodes still report v1.33.x — that is expected and normal
```

### Step 2 — Roll the node group to 1.34

Once you are happy with the control plane, bump `node_group_version` to match:

```hcl
cluster_version    = "1.34"   # unchanged
node_group_version = "1.34"   # now catch up
```

Apply — Terraform issues a rolling node replacement using `max_unavailable = 1`:

```bash
terraform apply
```

Watch the rolling node replacement:

```bash
watch -n5 kubectl get nodes
```

Verify apps stayed up throughout:

```bash
kubectl get pods
kubectl get pdb
```

### Step 3 — Upgrade control plane to 1.35

Same two-stage pattern — move the control plane first:

```hcl
cluster_version    = "1.35"   # was 1.34
node_group_version = "1.34"   # unchanged
```

In `addons.tf` update add-on versions for 1.35 (see the comments table in that file):

```hcl
addon_version = "v1.35.0-eksbuild.2"   # kube-proxy
addon_version = "v1.19.2-eksbuild.1"   # vpc-cni
addon_version = "v1.11.4-eksbuild.4"   # coredns
```

```bash
terraform apply
kubectl version --short
# Server: v1.35.x, nodes still on v1.34.x
```

### Step 4 — Roll the node group to 1.35

Once validated, catch up the nodes:

```hcl
cluster_version    = "1.35"   # unchanged
node_group_version = "1.35"   # catch up
```

```bash
terraform apply   # nodes rolling-replaced with AL2023 AMI for 1.35
watch -n5 kubectl get nodes
```

### Step 5 — Verify zero downtime

While step 4 is running in another terminal, hammer the apps continuously:

```bash
# Port-forward web-app locally
kubectl port-forward svc/web-app 8080:80 &
while true; do curl -sf http://localhost:8080 && echo " OK" || echo " FAIL"; sleep 0.5; done
```

You should see no FAILs thanks to PDBs and the rolling update strategy.

---

## Quick version lookup commands

```bash
# List available EKS versions in your region
aws eks describe-addon-versions --query 'addons[0].addonVersions[].compatibilities[].clusterVersion' \
  --output text | tr '\t' '\n' | sort -u

# Latest add-on version for a given k8s version
aws eks describe-addon-versions \
  --addon-name kube-proxy \
  --kubernetes-version 1.35 \
  --query 'addons[0].addonVersions[0].addonVersion' \
  --output text
```

---

## Clean up

```bash
kubectl delete -f apps/
terraform destroy
```

> **Cost estimate**: ~$0.10/hr for the NAT Gateways + ~$0.20/hr for the EKS control plane + EC2 nodes. Budget ~$3–5 for a full lab session.
