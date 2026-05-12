# Small Project — Option B: ECS + ECR + RDS + Blue/Green (CodeDeploy)

> **How to use this file:**
> Tell me "read the Option B README" and I will have full context of everything
> planned for this project and will know exactly what to build, how, and why.

---

## What This Project Is

The same **Calculator with History** app as Option A, but deployed on a production-grade
AWS stack: ECR for private image storage, ECS Fargate for serverless container orchestration,
RDS for a fully managed database, and AWS CodeDeploy for native Blue/Green deployment with
instant traffic switching via ALB.

**Key difference from Option A:** you never SSH into a server. The pipeline pushes an image,
updates a task definition, and CodeDeploy handles the rest. You operate at the service level,
not the machine level.

---

## The Three Microservices

| Service | Tech | Container Port | Responsibility |
|---|---|---|---|
| `frontend-service` | Nginx + HTML/CSS/JS | 80 | Serves the calculator UI |
| `calc-api` | Node.js 20 + Express | 3001 | Executes math operations |
| `history-api` | Python 3.12 + Flask | 3002 | Saves and reads history from DB |

The frontend calls `calc-api` for math and `history-api` for persistence.
The `history-api` is the only service that talks to RDS.

---

## Architecture

```
Internet
    |
    v
Application Load Balancer  (public, port 80/443)
    |                  |
    v                  v
TG Blue (v1)       TG Green (v2)     <- CodeDeploy manages the switch
    |                  |
    v                  v
ECS Tasks (v1)     ECS Tasks (v2)    <- Fargate, no EC2 to manage
    |
    v
RDS PostgreSQL                       <- managed, private subnet, automated backups
```

---

## Repository Structure

```
small-project/
├── .github/
│   └── workflows/
│       ├── dev.yml
│       ├── test.yml
│       └── prod.yml
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── src/
│       ├── index.html
│       ├── style.css
│       └── app.js
├── calc-api/
│   ├── Dockerfile
│   ├── package.json
│   └── src/index.js
├── history-api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py
├── docker-compose.yml           <- local dev (builds from source, uses local DB container)
├── appspec.yml                  <- CodeDeploy deployment specification
├── taskdef.json                 <- ECS task definition template (image URI injected by CI)
└── terraform/
    ├── bootstrap/
    │   ├── main.tf              <- creates S3 bucket + DynamoDB lock (run once)
    │   └── outputs.tf
    ├── modules/
    │   ├── vpc/
    │   ├── security_groups/
    │   ├── ecr/
    │   ├── ecs/
    │   ├── rds/
    │   ├── alb/
    │   └── iam/
    └── environments/
        └── small/
            └── option-b/
                ├── main.tf
                ├── variables.tf
                ├── outputs.tf
                └── terraform.tfvars
```

---

## Branch Strategy

```
main          <- source of truth, never commit directly here
  └── prod    <- live in ECS, CodeDeploy fires here
        └── test   <- staging, integration tests run here
              └── dev   <- active development
                    └── feature/*   <- where work happens
```

**Branch protection rules (set in GitHub):**
- `main`, `prod`, `test` require PRs — no direct push
- `main`, `prod`, `test` require status checks to pass before merge
- `prod` requires 1 approval on PR
- No force pushes on any protected branch

---

## CI/CD Pipeline

### `dev.yml` — triggers on push to `dev`
1. Checkout code
2. Lint: ESLint (calc-api), flake8 (history-api)
3. Unit tests: Jest (calc-api), pytest (history-api)
4. Build Docker images for all 3 services
5. Authenticate to ECR: `aws ecr get-login-password | docker login`
6. Push images to ECR tagged `:dev-<git-sha>`
7. Open automated PR: `dev` → `test`

### `test.yml` — triggers on push to `test`
1. Checkout code
2. Spin up docker-compose for integration tests (uses local DB container, not RDS)
3. Run integration tests (API reachability, DB read/write round-trip)
4. Tag images `:test-<git-sha>` in ECR
5. Open automated PR: `test` → `prod`

### `prod.yml` — triggers on push to `prod`
1. Checkout code
2. Tag existing ECR images as `:prod-<git-sha>` and `:latest`
3. Render new ECS task definition (inject new image URIs into `taskdef.json`)
4. Register new task definition revision with ECS
5. Trigger CodeDeploy Blue/Green deployment (`aws deploy create-deployment`)
6. Wait for deployment to reach `SUCCEEDED` state
7. **SUCCEEDED** → notify team
8. **FAILED** → CodeDeploy auto-rolls back to Blue, notify team

**No SSH. No docker-compose in production.** ECS and CodeDeploy manage everything.

### GitHub Secrets Required

| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` | All AWS CLI calls |
| `AWS_SECRET_ACCESS_KEY` | All AWS CLI calls |
| `AWS_ACCOUNT_ID` | ECR login URL: `<account>.dkr.ecr.<region>.amazonaws.com` |
| `AWS_REGION` | All AWS CLI calls |
| `ECS_CLUSTER_NAME` | prod.yml: register task definition |
| `ECS_SERVICE_NAME` | prod.yml: CodeDeploy deployment |
| `CODEDEPLOY_APP_NAME` | prod.yml: trigger deployment |
| `CODEDEPLOY_GROUP_NAME` | prod.yml: trigger deployment |

---

## Docker

### `docker-compose.yml` (local dev only)
- Builds all 3 services from source
- Includes a `db` service (postgres:15-alpine) for local development
- Services communicate by container name

### No `docker-compose.prod.yml`
Production uses ECS task definitions instead.
The `taskdef.json` file in the repo is the equivalent — it defines all 3 containers,
their image URIs, environment variables, and resource limits.

### ECR Image URI Pattern
```
<account>.dkr.ecr.<region>.amazonaws.com/small-frontend:prod-<sha>
<account>.dkr.ecr.<region>.amazonaws.com/small-calc-api:prod-<sha>
<account>.dkr.ecr.<region>.amazonaws.com/small-history-api:prod-<sha>
```

### `appspec.yml` (CodeDeploy spec)
```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: frontend
          ContainerPort: 80
```

### Dockerfile rules (same as Option A)
- Small base images: `node:20-alpine`, `python:3.12-slim`, `nginx:alpine`
- Non-root user
- `HEALTHCHECK` instruction on every image
- No secrets baked in — environment variables and AWS Secrets Manager only

---

## Terraform

### Module Philosophy
Each module is standalone with `main.tf`, `variables.tf`, `outputs.tf`.
Option B uses 7 modules. All of them (except `ec2`) are reused in medium and big projects.

### `bootstrap/` — run once before anything else
Creates the S3 bucket and DynamoDB table used for remote state.
Apply with local state, then never touch again.

### Remote State
```hcl
backend "s3" {
  bucket         = "your-tf-state-bucket"
  key            = "small/option-b/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-lock"
}
```

### Module: `vpc`
- VPC with CIDR `10.0.0.0/16`
- 2 public subnets (2 AZs) — for ALB
- 2 private subnets (2 AZs) — for ECS tasks and RDS
- Internet Gateway, NAT Gateway, route tables
- **Outputs:** `vpc_id`, `public_subnet_ids`, `private_subnet_ids`

### Module: `security_groups`
- **ALB SG:** inbound 80/443 from `0.0.0.0/0`
- **ECS Tasks SG:** inbound 3001/3002 from ALB SG only
- **RDS SG:** inbound 5432 from ECS Tasks SG only
- **Outputs:** `alb_sg_id`, `ecs_tasks_sg_id`, `rds_sg_id`

### Module: `ecr`
- 3 ECR repositories: `small-frontend`, `small-calc-api`, `small-history-api`
- Lifecycle policy: keep last 10 tagged images, delete untagged after 1 day
- **Outputs:** `frontend_repo_url`, `calc_api_repo_url`, `history_api_repo_url`

### Module: `ecs`
- ECS cluster
- Task definition with all 3 containers, resource limits, log group
- ECS service with CodeDeploy deployment controller (enables Blue/Green)
- **Inputs:** image URIs, task execution role ARN, subnet IDs, security group IDs
- **Outputs:** `cluster_name`, `service_name`, `task_definition_arn`

### Module: `rds`
- RDS PostgreSQL 15, instance class `db.t3.micro`
- Subnet group using private subnets
- Automated backups (7-day retention)
- Deletion protection: `true` in prod
- Password stored in AWS Secrets Manager (not in Terraform state)
- **Outputs:** `db_endpoint`, `db_name`, `db_port`

### Module: `alb`
- Application Load Balancer (internet-facing, public subnets)
- Target Group Blue (health check `/health`)
- Target Group Green (health check `/health`)
- Listener on port 80, initial forward to TG Blue
- **Outputs:** `alb_dns_name`, `tg_blue_arn`, `tg_green_arn`, `listener_arn`

### Module: `iam`
- ECS task execution role: allows ECR image pull + CloudWatch Logs write
- CodeDeploy role: allows ECS Blue/Green deployment management
- **Outputs:** `ecs_task_execution_role_arn`, `codedeploy_role_arn`

### `environments/small/option-b/main.tf` calls
```
module "vpc"              → modules/vpc
module "security_groups"  → modules/security_groups
module "ecr"              → modules/ecr
module "iam"              → modules/iam
module "rds"              → modules/rds
module "alb"              → modules/alb
module "ecs"              → modules/ecs
```

---

## AWS Infrastructure

### Network Layout

| Subnet | Type | AZ | What Lives Here |
|---|---|---|---|
| `10.0.1.0/24` | Public | us-east-1a | ALB only |
| `10.0.2.0/24` | Public | us-east-1b | ALB only |
| `10.0.3.0/24` | Private | us-east-1a | ECS Tasks + RDS primary |
| `10.0.4.0/24` | Private | us-east-1b | ECS Tasks + RDS standby |

### Security Groups

| Security Group | Inbound | Outbound |
|---|---|---|
| ALB SG | 80 from `0.0.0.0/0` | All |
| ECS Tasks SG | 3001/3002 from ALB SG only | All |
| RDS SG | 5432 from ECS Tasks SG only | All |

### Blue/Green Deployment Flow (CodeDeploy)

```
Step 1: New ECS tasks (v2) start in TG Green
        ALB routes 100% traffic to TG Blue (v1)

Step 2: CodeDeploy health checks Green tasks
        Fail -> deployment fails, Blue stays live, auto-rollback

Step 3: Health checks pass
        CodeDeploy shifts ALB: 100% to TG Green (v2)

Step 4: Blue (v1) tasks kept alive for termination_wait_time (default 60 min)
        Instant rollback: one API call shifts ALB back to Blue

Step 5: After wait time, Blue (v1) tasks terminated
```

### Cost Estimate

| Resource | Spec | Monthly |
|---|---|---|
| ECS Fargate | 0.25 vCPU / 0.5 GB x 3 tasks | ~$9 |
| RDS PostgreSQL | db.t3.micro, 20 GB gp2 | ~$15 |
| ECR | 3 repos, ~1 GB storage | ~$0.10 |
| ALB | per LCU | ~$16 |
| NAT Gateway | 1x + per GB data | ~$32 |
| **Total** | | **~$72/month** |

> The NAT Gateway is the biggest cost driver. For a learning project you can run ECS tasks
> in public subnets to eliminate it, but private subnets + NAT is the correct architecture.

---

## Build Order

| Week | Task |
|---|---|
| 1 | Write the 3 services. Get `docker-compose up` running locally. Test all APIs. |
| 2 | Create GitHub repo. 4 branches. Branch protection. Add `appspec.yml` + `taskdef.json`. |
| 3 | Write `dev.yml` and `test.yml` with ECR push. Verify images appear in ECR. |
| 4 | Run `bootstrap/`. Build `modules/vpc`, `security_groups`, `ecr`, `iam`. Apply. Verify in AWS. |
| 5 | Build `modules/rds`, `ecs`, `alb`. Apply `option-b` environment. Verify ECS tasks run. |
| 6 | Write `prod.yml` with CodeDeploy trigger. Full end-to-end: push → ECR → ECS → B/G swap. |

---

## Module Reuse Across Future Projects

| Module | Small A | Small B | Medium | Big |
|---|---|---|---|---|
| `vpc` | Y | Y | Y | Y |
| `security_groups` | Y | Y | Y | Y |
| `ec2` | Y (x3) | - | - | - |
| `alb` | Y | Y | Y | Y |
| `ecr` | - | Y | Y | Y |
| `ecs` | - | Y | Y | - |
| `rds` | - | Y | Y | Y |
| `iam` | - | Y | Y | Y |
| `eks` | - | - | - | Y |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML5 + CSS3 + Vanilla JS served by Nginx |
| Calc API | Node.js 20 + Express |
| History API | Python 3.12 + Flask + SQLAlchemy |
| Database | AWS RDS PostgreSQL 15 (managed, private subnet) |
| Container orchestration | AWS ECS Fargate (serverless, no EC2 to manage) |
| Image registry | AWS ECR (private, IAM-authenticated) |
| Blue/Green | AWS CodeDeploy (ECS deployment type) |
| CI/CD | GitHub Actions (3 workflows) |
| Infrastructure as Code | Terraform (module-based, S3 remote state) |

---

## What This Project Proves

- Designing and deploying microservices on a fully managed AWS stack
- Understanding ECS Fargate: task definitions, services, container networking
- Using ECR as a private registry with IAM authentication (no stored credentials)
- Blue/Green deployment at the platform level: CodeDeploy manages the swap, not a script
- Writing 7 reusable Terraform modules that will be directly reused in medium and big projects
- Securing AWS with proper subnet isolation: public for ALB, private for compute and DB
- Operating without SSH: infrastructure managed entirely through AWS APIs
