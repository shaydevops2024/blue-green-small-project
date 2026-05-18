#!/bin/bash
set -e

cd "$(dirname "$0")/../terraform/environments/small/option-a"

echo "Reading terraform outputs..."

terraform output -raw listener_arn          | gh secret set LISTENER_ARN
terraform output -raw blue_target_group_arn | gh secret set BLUE_TG_ARN
terraform output -raw green_target_group_arn| gh secret set GREEN_TG_ARN
terraform output -raw blue_public_ip        | gh secret set BLUE_PUBLIC_IP
terraform output -raw green_public_ip       | gh secret set GREEN_PUBLIC_IP

echo "All secrets set."
