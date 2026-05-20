terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "blue-green-small-tfstate-shayg-test"
    key            = "small/option-b/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "blue-green-small-tfstate-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "../../../modules/vpc"

  project_name  = var.project_name
  aws_region    = var.aws_region
  vpc_cidr      = var.vpc_cidr
  subnet_a_cidr = var.subnet_a_cidr
  subnet_b_cidr = var.subnet_b_cidr
}

module "ecr" {
  source = "../../../modules/ecr"

  project_name = var.project_name
}

module "rds" {
  source = "../../../modules/rds"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  subnet_a_id       = module.vpc.subnet_a_id
  subnet_b_id       = module.vpc.subnet_b_id
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
}

module "ecs" {
  source = "../../../modules/ecs"

  project_name      = var.project_name
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  subnet_a_id       = module.vpc.subnet_a_id
  subnet_b_id       = module.vpc.subnet_b_id
  frontend_image    = "${module.ecr.frontend_repo_url}:prod-latest"
  calc_api_image    = "${module.ecr.calc_api_repo_url}:prod-latest"
  history_api_image = "${module.ecr.history_api_repo_url}:prod-latest"
  db_host           = module.rds.endpoint
  db_port           = module.rds.port
  db_name           = var.db_name
  db_user           = var.db_username
  db_password       = var.db_password
}
