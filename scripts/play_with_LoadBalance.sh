#!/bin/bash
set -e

TERRAFORM_DIR="$(dirname "$0")/../terraform/environments/small/option-a"

echo "Reading Terraform outputs..."
LISTENER_ARN=$(terraform -chdir="$TERRAFORM_DIR" output -raw listener_arn | tr -d '[:space:]')
BLUE_TG=$(terraform -chdir="$TERRAFORM_DIR" output -raw blue_target_group_arn | tr -d '[:space:]')
GREEN_TG=$(terraform -chdir="$TERRAFORM_DIR" output -raw green_target_group_arn | tr -d '[:space:]')

echo "Listener: $LISTENER_ARN"

# Determine current active slot and weights
TG_JSON=$(aws elbv2 describe-listeners \
  --region us-east-1 \
  --listener-arns "$LISTENER_ARN" \
  --query 'Listeners[0].DefaultActions[0].ForwardConfig.TargetGroups' \
  --output json)

BLUE_WEIGHT=$(echo "$TG_JSON" | jq -r --arg arn "$BLUE_TG" '.[] | select(.TargetGroupArn == $arn) | .Weight')
GREEN_WEIGHT=$(echo "$TG_JSON" | jq -r --arg arn "$GREEN_TG" '.[] | select(.TargetGroupArn == $arn) | .Weight')

echo ""
echo "Current load distribution:"
echo "  Blue:  ${BLUE_WEIGHT}%"
echo "  Green: ${GREEN_WEIGHT}%"
echo ""
echo "Choose a new distribution:"
echo "  1) 100% Blue  /   0% Green"
echo "  2)  80% Blue  /  20% Green"
echo "  3)  50% Blue  /  50% Green"
echo "  4)  20% Blue  /  80% Green"
echo "  5)   0% Blue  / 100% Green"
echo "  6) Custom"
echo ""
read -rp "Enter choice [1-6]: " CHOICE

case "$CHOICE" in
  1) BW=100; GW=0 ;;
  2) BW=80;  GW=20 ;;
  3) BW=50;  GW=50 ;;
  4) BW=20;  GW=80 ;;
  5) BW=0;   GW=100 ;;
  6)
    read -rp "Blue weight (0-100): " BW
    GW=$((100 - BW))
    if [ "$GW" -lt 0 ] || [ "$BW" -gt 100 ]; then
      echo "Invalid weight. Must be between 0 and 100."
      exit 1
    fi
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac

echo ""
echo "Applying: Blue=${BW}%  Green=${GW}%..."

aws elbv2 modify-listener \
  --region us-east-1 \
  --listener-arn "$LISTENER_ARN" \
  --default-actions "$(jq -n \
    --arg blue "$BLUE_TG" \
    --arg green "$GREEN_TG" \
    --argjson bw "$BW" \
    --argjson gw "$GW" \
    '[{"Type":"forward","ForwardConfig":{"TargetGroups":[{"TargetGroupArn":$blue,"Weight":$bw},{"TargetGroupArn":$green,"Weight":$gw}]}}]')" \
  > /dev/null

echo "Done. New distribution: Blue=${BW}%  Green=${GW}%"
