#!/bin/bash
set -e

DB_PASS="$1"

cd "$(dirname "$0")/../../terraform/environments/small/option-b"

echo "Reading terraform outputs..."

terraform output -raw frontend_repo_url      | gh secret set FRONTEND_REPO_URL
terraform output -raw calc_api_repo_url      | gh secret set CALC_API_REPO_URL
terraform output -raw history_api_repo_url   | gh secret set HISTORY_API_REPO_URL
terraform output -raw codedeploy_app_name    | gh secret set CODEDEPLOY_APP_NAME
terraform output -raw codedeploy_deployment_group | gh secret set CODEDEPLOY_DEPLOYMENT_GROUP
terraform output -raw cluster_name           | gh secret set ECS_CLUSTER_NAME
terraform output -raw service_name           | gh secret set ECS_SERVICE_NAME
terraform output -raw listener_arn           | gh secret set LISTENER_ARN
terraform output -raw blue_target_group_arn  | gh secret set BLUE_TG_ARN
terraform output -raw green_target_group_arn | gh secret set GREEN_TG_ARN

echo "$DB_PASS" | gh secret set DB_PASSWORD

echo "All secrets set."
