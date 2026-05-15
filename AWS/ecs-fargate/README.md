# ECS Fargate Lab

A minimal but production-shaped ECS Fargate setup on AWS.  
Provisions a Fargate service running nginx behind an Application Load Balancer, across two private subnets.

## Architecture

```
eu-north-1
├── VPC  10.0.0.0/16
│   ├── Public subnets  ×2 AZs  — ALB
│   └── Private subnets ×2 AZs  — Fargate tasks
│
├── Internet Gateway + NAT Gateway
│   └── Tasks in private subnets can pull images; inbound only through ALB
│
├── Application Load Balancer  (port 80)
│   └── Target Group (target_type = ip)
│       └── ECS Service  (desired_count = 2)
│           └── Task Definition  (nginx, 0.25 vCPU / 512 MiB)
│
└── CloudWatch Log Group  /ecs/ecs-lab
```

## Key concepts

| Concept | This lab |
|---|---|
| **Task Definition** | Blueprint: image, CPU/mem, ports, log config. Versioned — every `terraform apply` that changes it creates a new revision. |
| **Service** | Keeps `desired_count` tasks running, handles rolling updates, registers tasks in the target group. |
| **awsvpc network mode** | Each task gets its own ENI + private IP. Security groups attach to tasks, not hosts. |
| **Task Execution Role** | Used by the ECS agent to pull images and write logs. |
| **Task Role** | Used by your application code at runtime to call AWS APIs. |

## Step 1 — Provision the lab (v1)

`app_version` defaults to `v1`. Just init and apply:

```bash
cd ecs-fargate/

terraform init
terraform apply
```

Confirm v1 is serving:

```bash
endpoint=`terraform output -raw alb_dns_name`
while true; do curl $endpoint; done
# <h1>v1</h1>
```

Keep a continuous loop running in a second terminal to watch traffic during the upgrade:

```bash
endpoint=`terraform output -raw alb_dns_name`
while true; do curl $endpoint; done
```

## Step 2 — Deploy v2

In `variables.tf`, change `app_version`:

```hcl
app_version = "v2"
```

Apply — this registers a new task definition revision but **does not update the running service**
(because of `lifecycle { ignore_changes = [task_definition] }`):

```bash
terraform apply
```

Now explicitly tell the service to roll to the new revision:

```bash
aws ecs update-service \
  --cluster ecs-lab-cluster \
  --service ecs-lab-service \
  --task-definition ecs-lab-app \
  --force-new-deployment \
  --region eu-north-1 > /dev/null
```

## Step 3 — Observe the rolling update

Watch the task count — you will see 4 tasks briefly (2×v1 + 2×v2) before the v1 tasks
drain and stop (`deregistration_delay = 30s`):

```bash
watch -n3 "aws ecs describe-services \
  --cluster ecs-lab-cluster \
  --services ecs-lab-service \
  --region eu-north-1 \
  --query 'services[0].{running:runningCount,pending:pendingCount}'"
```

In the curl loop you should see responses flip from `v1` to `v2` with no gaps.
Once stable, verify:

```bash
endpoint=`terraform output -raw alb_dns_name`
while true; do curl $endpoint; done
# <h1>v2</h1>
```

## Clean up

```bash
terraform destroy
```

> **Cost estimate**: ~$0.10/hr NAT Gateway + ~$0.04/hr for 2 Fargate tasks (0.25 vCPU / 512 MiB) + ~$0.02/hr ALB. Budget ~$1–2 for a short lab session.
