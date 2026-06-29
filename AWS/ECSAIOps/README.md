# ECS AIOps — AWS DevOps Guru Anomaly Detection Demo

## Goal

This project provisions a minimal AWS environment to demonstrate **AWS DevOps Guru** performing AI-powered anomaly detection on an ECS Fargate workload. The core idea is:

1. Deploy a healthy containerised application on ECS Fargate.
2. At any point, swap to a **defective image** that leaks memory.
3. DevOps Guru detects the rising memory trend (via CloudWatch Container Insights) and raises an insight, delivering a notification to an SNS email subscription.

It is a learning/demo sandbox, not a production setup.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                      │
│  ┌──────────────────────┐  ┌──────────────────────────┐ │
│  │  Public Subnet AZ-0  │  │  Public Subnet AZ-1      │ │
│  │  10.0.0.0/24         │  │  10.0.1.0/24             │ │
│  └──────────┬───────────┘  └─────────────┬────────────┘ │
│             │  ECS Fargate Task           │              │
└─────────────┼─────────────────────────────┼─────────────┘
              │                             │
              └──────────┬──────────────────┘
                         │ Internet Gateway
                         ▼
                    (Public Internet)

ECR Repository
  └── :healthy   (normal app)
  └── :defective (memory-leaking app — built manually)

ECS Cluster (Container Insights enabled)
  └── Fargate Service → Task Definition → app:healthy (initial)
        └── CloudWatch Logs  (/ecs/ecs-aiops)

DevOps Guru
  └── Resource Collection (tag: DevOpsGuruEnabled=true)
  └── Notification Channel → SNS Topic → Email subscription
```

---

## AWS Resources

| File | Resources |
|---|---|
| `vpc.tf` | VPC, 2 public subnets, Internet Gateway, route table, ECS security group (port 8080 inbound) |
| `ecr.tf` | ECR repository (`ecs-aiops-app`) with mutable tags |
| `ecs.tf` | ECS cluster (Container Insights on), IAM task execution role, CloudWatch log group, Fargate task definition, ECS service |
| `devopsguru.tf` | SNS topic + email subscription, DevOps Guru resource collection (tag-based), DevOps Guru notification channel |
| `main.tf` | Terraform / AWS provider configuration |
| `variables.tf` | Input variables (region, project name, notification email, CPU/memory) |
| `outputs.tf` | ECR URL, cluster name, service name, SNS ARN, log group name |

### Tag-based monitoring

Every resource that should be monitored by DevOps Guru carries the tag:

```
DevOpsGuruEnabled = "true"
```

The `aws_devopsguru_resource_collection` resource scans all tagged resources automatically — no manual resource list is needed.

---

## Application (`app/`)

A minimal Python 3.12 HTTP server that listens on port 8080 and responds with its current RSS memory usage.

### Healthy image
Responds normally, memory stays flat.

### Defective image (OOM simulation)
The commented-out block in `app.py` activates a **gradual cache leak**: 1 000 UUID-keyed 10 KB strings are written to an in-memory dict every second. On a 512 MB Fargate task this exhausts memory in roughly 30–45 minutes, producing the rising `MemoryUtilization` trend that DevOps Guru is designed to detect.

To build the defective image, uncomment the `_leak` thread block in `app/app.py` before building.

---

## Default Variables

| Variable | Default | Description |
|---|---|---|
| `region` | `eu-north-1` | AWS region |
| `project` | `ecs-aiops` | Prefix for all resource names |
| `notification_email` | *(set in variables.tf)* | Email for DevOps Guru alerts |
| `task_cpu` | `256` | Fargate task CPU units (0.25 vCPU) |
| `task_memory` | `512` | Fargate task memory (MB) |

---

## Prerequisites

> **Before running `terraform apply` you must set your notification email.**
> DevOps Guru will send SNS alerts to this address. There is no default — omitting it will cause Terraform to prompt (or error in automation).

Create a `terraform.tfvars` file **(do not commit it)**:

```hcl
# terraform.tfvars
notification_email = "you@example.com"
```

Or pass it inline:

```bash
terraform apply -var="notification_email=you@example.com"
```

After deploying, **confirm the SNS subscription** by clicking the confirmation link AWS sends to that address — without this step DevOps Guru notifications will not be delivered.

---

## Estimated Cost

Prices are based on the **eu-north-1 (Stockholm)** region as of mid-2025. All figures are approximate.

| Service | What runs | $/hour | $/day |
|---|---|---|---|
| ECS Fargate | 1 task · 0.25 vCPU · 0.5 GB | ~$0.015 | ~$0.36 |
| AWS DevOps Guru | ~10 tagged resources | ~$0.028 | ~$0.67 |
| CloudWatch Container Insights | 1 ECS cluster / log ingestion | ~$0.003 | ~$0.07 |
| ECR | 1 repository · small images | < $0.01 | < $0.01 |
| SNS | Email notifications (free tier) | $0.00 | $0.00 |

**Typical lab session estimates:**

| Scenario | Duration | Estimated cost |
|---|---|---|
| Quick smoke test | 2 hours | ~$0.10 |
| Full anomaly detection cycle | 8 hours | ~$0.40 |
| Left running overnight | 24 hours | ~$1.10 |

> **Key cost driver:** AWS DevOps Guru charges **$0.0028 per resource-hour** for every resource in the monitored collection. With ~10 tagged resources this is roughly $0.67/day. Tear down the stack as soon as you are done with the lab.

> **DevOps Guru baseline period:** The service needs several hours of metric history before it can reliably flag anomalies. Plan for at least a **4–6 hour window** between deploying the defective image and expecting an insight.

To avoid unexpected charges, run `terraform destroy` at the end of each session.

---

## Usage

### 1. Deploy infrastructure

```bash
terraform init
terraform apply
```

### 2. Build and push the healthy image

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin "$ECR_URL"

docker build -t "$ECR_URL:healthy" app/
docker push "$ECR_URL:healthy"
```

### 3. Force a new ECS deployment (pick up the image)

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment
```

### 4. Trigger the anomaly

Uncomment the `_leak` thread block in `app/app.py`, then build and push a defective image:

```bash
docker build -t "$ECR_URL:defective" app/
docker push "$ECR_URL:defective"
```

Update the task definition image tag to `:defective` (edit `ecs.tf` or pass it as a variable), then run `terraform apply` again and force a new deployment.

### 5. Wait for DevOps Guru

DevOps Guru needs a baseline period (typically a few hours) before it can flag anomalies. Once memory utilisation trends upward consistently, it will open an insight and send a notification to the configured email address via SNS.

---

## Cleanup

```bash
terraform destroy
```

> **Note:** The ECR repository has `force_delete = true`, so it will be deleted even if it contains images.
