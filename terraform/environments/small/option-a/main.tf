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
    key            = "small/option-a/terraform.tfstate"
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

module "security_groups" {
  source = "../../../modules/security_groups"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "ec2" {
  source = "../../../modules/ec2"

  project_name  = var.project_name
  ami_id        = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  ec2_sg_id     = module.security_groups.ec2_sg_id
  subnet_a_id   = module.vpc.subnet_a_id
  subnet_b_id   = module.vpc.subnet_b_id
}

module "alb" {
  source = "../../../modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  subnet_a_id       = module.vpc.subnet_a_id
  subnet_b_id       = module.vpc.subnet_b_id
  alb_sg_id         = module.security_groups.alb_sg_id
  blue_instance_id  = module.ec2.blue_instance_id
  green_instance_id = module.ec2.green_instance_id
}