# Small Project — Option A: EC2 + DockerHub + ALB + Blue/Green

> **How to use this file:**
> Tell me "read the Option A README" and I will have full context of everything
> planned for this project and will know exactly what to build, how, and why.

---

## What This Project Is

A **Calculator with History** web app that demonstrates real microservices communication,
a full CI/CD pipeline across three branches, and Blue/Green deployment with zero downtime
on AWS EC2 — using an Application Load Balancer to switch traffic between two live instances.

The app is intentionally simple. The point is the infrastructure and pipeline around it.

---

## The Three Microservices

| Service | Tech | Port | Responsibility |
|---|---|---|---|
| `frontend-service` | Nginx + HTML/CSS/JS | 80 | Serves the calculator UI |
| `calc-api` | Node.js 20 + Express | 3001 | Executes math operations |
| `history-api` | Python 3.12 + Flask | 3002 | Saves and reads history from DB |

The frontend calls `calc-api` for math and `history-api` for persistence.
The `history-api` is the only service that talks to the database.

---

## Architecture

```
Internet
    |
    v
Application Load Balancer  (public, port 80)
    |                   |
    v                   v
TG-Blue             TG-Green
    |                   |
    v                   v
EC2 Blue           EC2 Green        <- only ONE receives traffic at a time
  [frontend]         [frontend]
  [calc-api]         [calc-api]
  [history-api]      [history-api]
       |                  |
       +--------+---------+
                |
                v
            EC2 DB                  <- always-on, never swapped
           [PostgreSQL 15]
```

**Why a separate DB instance:** Both Blue and Green app instances point to the same
Postgres container on EC2 DB. This way, switching traffic never causes data inconsistency.
The DB is not part of the Blue/Green swap.

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
├── docker-compose.yml           <- local dev (builds from source)
├── docker-compose.prod.yml      <- production (pulls from DockerHub)
└── terraform/
    ├── bootstrap/
    │   ├── main.tf              <- creates S3 bucket + DynamoDB lock (run once)
    │   └── outputs.tf
    ├── modules/
    │   ├── vpc/
    │   ├── security_groups/
    │   ├── ec2/
    │   └── alb/
    └── environments/
        └── small/
            └── option-a/
                ├── main.tf
                ├── variables.tf
                ├── outputs.tf
                └── terraform.tfvars
```

---

## Branch Strategy

```
main          <- source of truth, never commit directly here
  └── prod    <- what is live in AWS, Blue/Green swap fires here
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
5. Push to DockerHub tagged `:dev-<git-sha>`
6. Open automated PR: `dev` → `test`

### `test.yml` — triggers on push to `test`
1. Checkout code
2. Spin up full stack via docker-compose (app + test DB container)
3. Run integration tests (API reachability, DB read/write round-trip)
4. Tag images `:test-<git-sha>` and push to DockerHub
5. Open automated PR: `test` → `prod`

### `prod.yml` — triggers on push to `prod`
1. Read SSM Parameter `/small/active-color` → e.g. `blue`
2. Set `INACTIVE = green`
3. Get INACTIVE instance IP from SSM `/small/green-ip`
4. SSH into INACTIVE EC2
5. `docker-compose pull` (new images from DockerHub)
6. `docker-compose -f docker-compose.prod.yml up -d`
7. Health check: `curl http://<inactive-ip>/health` (retry 10x, 5s apart)
8. **PASSED** → switch ALB listener to INACTIVE target group (AWS CLI)
9. Write SSM `/small/active-color = green`
10. **FAILED** → abort, Blue stays live, team is notified

**The old instance stays running** after the swap. Rollback is one AWS CLI call.

### GitHub Secrets Required

| Secret | Purpose |
|---|---|
| `DOCKERHUB_USERNAME` | Push images |
| `DOCKERHUB_TOKEN` | Push images |
| `AWS_ACCESS_KEY_ID` | AWS CLI in prod |
| `AWS_SECRET_ACCESS_KEY` | AWS CLI in prod |
| `EC2_SSH_KEY` | SSH into instances |
| `ALB_LISTENER_ARN` | Switch target group |
| `TG_BLUE_ARN` | Target group Blue ARN |
| `TG_GREEN_ARN` | Target group Green ARN |

---

## Docker

### `docker-compose.yml` (local dev)
- Builds all 3 services from source
- Includes a `db` service (postgres:15-alpine) for local development
- Services communicate by container name (`DB_HOST: db`)

### `docker-compose.prod.yml` (production)
- Pulls images from DockerHub using `${DOCKERHUB_USER}/servicename:${IMAGE_TAG}`
- No `db` service — the DB runs on its own EC2 instance
- `DB_HOST` env var points to the EC2 DB private IP
- All services have `restart: always`

### Dockerfile rules (all services)
- Small base image: `node:20-alpine`, `python:3.12-slim`, `nginx:alpine`
- Non-root user
- `HEALTHCHECK` instruction on every image
- No secrets baked in — environment variables only

---

## Terraform

### Module Philosophy
Each module is standalone with `main.tf`, `variables.tf`, `outputs.tf`.
Environments call modules with different variables.
The `ec2` module is called three times (blue, green, db) — same module, different inputs.

### `bootstrap/` — run once before anything else
Creates the S3 bucket and DynamoDB table used for remote state.
Apply with local state, then never touch again.

### Remote State
```hcl
backend "s3" {
  bucket         = "your-tf-state-bucket"
  key            = "small/option-a/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-lock"
}
```

### Module: `vpc`
- VPC with CIDR `10.0.0.0/16`
- 2 public subnets in 2 AZs (required for ALB)
- Internet Gateway + route table
- **Outputs:** `vpc_id`, `public_subnet_ids`

### Module: `security_groups`
- **ALB SG:** inbound 80 from `0.0.0.0/0`
- **App SG:** inbound 80 from ALB SG only, 22 from `var.your_ip`
- **DB SG:** inbound 5432 from App SG only, 22 from `var.your_ip`
- **Outputs:** `alb_sg_id`, `app_sg_id`, `db_sg_id`

### Module: `ec2`
- Single EC2 instance (call 3 times for blue, green, db)
- Elastic IP, key pair association
- `user_data` bootstrap: installs Docker + Docker Compose, pulls `docker-compose.prod.yml` from GitHub, runs `docker-compose up -d`
- **Inputs:** `name`, `subnet_id`, `security_group_id`, `instance_type`, `key_name`
- **Outputs:** `instance_id`, `private_ip`, `public_ip`

### Module: `alb`
- Application Load Balancer (internet-facing)
- Target Group Blue (health check `/health`, port 80)
- Target Group Green (health check `/health`, port 80)
- Listener on port 80, initial forward to TG Blue
- **Inputs:** `vpc_id`, `subnet_ids`, `security_group_id`, `blue_instance_id`, `green_instance_id`
- **Outputs:** `alb_dns_name`, `tg_blue_arn`, `tg_green_arn`, `listener_arn`

### `environments/small/option-a/main.tf` calls
```
module "vpc"              → modules/vpc
module "security_groups"  → modules/security_groups
module "ec2_blue"         → modules/ec2   (name = "blue",  subnet = public[0])
module "ec2_green"        → modules/ec2   (name = "green", subnet = public[1])
module "ec2_db"           → modules/ec2   (name = "db",    subnet = public[0])
module "alb"              → modules/alb
```

---

## AWS Infrastructure

### EC2 Instances

| Instance | Type | AZ | Role |
|---|---|---|---|
| EC2 Blue | t3.micro | us-east-1a | App containers (active or inactive) |
| EC2 Green | t3.micro | us-east-1b | App containers (active or inactive) |
| EC2 DB | t3.micro | us-east-1a | PostgreSQL 15, always-on |

### SSM Parameter Store

| Parameter | Value | Purpose |
|---|---|---|
| `/small/active-color` | `blue` or `green` | Which instance currently serves traffic |
| `/small/blue-ip` | EC2 Blue private IP | SSH target in prod.yml |
| `/small/green-ip` | EC2 Green private IP | SSH target in prod.yml |

SSM parameters for IPs are written by Terraform via `aws_ssm_parameter` resources in the `ec2` module.

### Cost Estimate

| Resource | Monthly |
|---|---|
| 3x EC2 t3.micro | ~$23 |
| 1x ALB | ~$16 |
| SSM, DockerHub free tier | $0 |
| **Total** | **~$39/month** |

---

## Build Order

| Week | Task |
|---|---|
| 1 | Write the 3 services locally. Get `docker-compose up` running. Test all 3 talking. |
| 2 | Create GitHub repo. Set up 4 branches. Configure branch protection rules. |
| 3 | Write `dev.yml` and `test.yml`. Push to dev, verify pipeline runs and images appear in DockerHub. |
| 4 | Run `bootstrap/`. Build `modules/vpc` and `modules/security_groups`. |
| 5 | Build `modules/ec2` and `modules/alb`. Apply `option-a` env. Verify 3 EC2s + ALB in AWS. |
| 6 | Write `prod.yml`. Full end-to-end: push to dev → images build → PRs open → merge → deploys → ALB swaps. |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML5 + CSS3 + Vanilla JS served by Nginx |
| Calc API | Node.js 20 + Express |
| History API | Python 3.12 + Flask + SQLAlchemy |
| Database | PostgreSQL 15 (Docker container on EC2 DB) |
| Container runtime | Docker + Docker Compose |
| Image registry | DockerHub (free tier) |
| CI/CD | GitHub Actions (3 workflows) |
| Infrastructure as Code | Terraform (module-based, S3 remote state) |
| Cloud | AWS: EC2, ALB, VPC, Security Groups, SSM Parameter Store |

---

## What This Project Proves

- Designing a microservices architecture with real inter-service HTTP calls
- Full CI/CD discipline: branch flow, automated PRs, image tagging by SHA
- Blue/Green deployment with zero downtime and instant rollback
- Writing Terraform in reusable modules that will scale to medium and big projects
- Understanding Docker networking (services calling each other by container name)
- Securing AWS infrastructure: private app ports, SG chaining, SSH restricted to your IP
