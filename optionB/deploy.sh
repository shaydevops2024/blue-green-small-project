#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform/environments/small/option-b"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── GitHub auth check ─────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}Checking GitHub authentication...${NC}"

if ! gh auth status &>/dev/null; then
  echo -e "${YELLOW}You are not authenticated to GitHub yet.${NC}"
  echo -e "Running ${BOLD}gh auth login${NC}...\n"
  gh auth login
  echo ""
fi

echo -e "${GREEN}GitHub authentication confirmed.${NC}\n"

# ── DB password ───────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}Database password setup${NC}"
echo -e "${YELLOW}This password will be used for the RDS PostgreSQL instance.${NC}"
echo -e "${YELLOW}It will also be saved as a GitHub secret (DB_PASSWORD) for the CI pipeline.${NC}\n"

while true; do
  read -rsp "$(echo -e "${BOLD}Enter DB password:${NC} ")" DB_PASS
  echo ""
  read -rsp "$(echo -e "${BOLD}Confirm DB password:${NC} ")" DB_PASS_CONFIRM
  echo ""

  if [ "$DB_PASS" = "$DB_PASS_CONFIRM" ]; then
    break
  else
    echo -e "${RED}Passwords do not match. Try again.${NC}\n"
  fi
done

export TF_VAR_db_password="$DB_PASS"
echo -e "${GREEN}Password set for this session.${NC}\n"

# ── Menu ──────────────────────────────────────────────────────────────────────
echo -e "${BOLD}What do you want to do?${NC}"
echo -e "  ${CYAN}1)${NC} terraform init"
echo -e "  ${CYAN}2)${NC} terraform plan"
echo -e "  ${CYAN}3)${NC} terraform apply"
echo -e "  ${CYAN}4)${NC} terraform destroy"
echo ""
read -rp "$(echo -e "${BOLD}Enter your choice [1-4]:${NC} ")" choice

cd "$TF_DIR"

do_plan() {
  echo -e "\n${BOLD}${CYAN}Running terraform plan...${NC}\n"
  terraform plan

  echo ""
  read -rp "$(echo -e "${BOLD}Continue to apply? [y/N]:${NC} ")" cont
  if [[ "$cont" =~ ^[Yy]$ ]]; then
    do_apply
  fi
}

do_apply() {
  echo -e "\n${BOLD}${CYAN}Running terraform apply...${NC}\n"
  terraform apply

  echo -e "\n${BOLD}${CYAN}Pushing terraform outputs and secrets to GitHub...${NC}\n"
  bash "$SCRIPT_DIR/scripts/set-gh-secrets.sh" "$DB_PASS"
}

case "$choice" in
  1)
    echo -e "\n${BOLD}${CYAN}Running terraform init...${NC}\n"
    terraform init

    echo ""
    echo -e "${BOLD}Continue with:${NC}"
    echo -e "  ${CYAN}1)${NC} plan"
    echo -e "  ${CYAN}2)${NC} apply"
    echo -e "  ${CYAN}3)${NC} nothing — exit"
    echo ""
    read -rp "$(echo -e "${BOLD}Enter your choice [1-3]:${NC} ")" next
    case "$next" in
      1) do_plan ;;
      2) do_apply ;;
      *) echo -e "\n${YELLOW}Exiting.${NC}" ;;
    esac
    ;;
  2)
    do_plan
    ;;
  3)
    do_apply
    ;;
  4)
    echo -e "\n${BOLD}${RED}Running terraform destroy...${NC}\n"
    terraform destroy
    ;;
  *)
    echo -e "\n${YELLOW}Invalid choice. Exiting.${NC}"
    exit 1
    ;;
esac

echo -e "\n${GREEN}${BOLD}Done.${NC}"
