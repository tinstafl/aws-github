#!/bin/bash

# delete.sh -a <aws_account_id> [-r <role_name>] [-w <aws_region>] [-p <oidc_provider_arn>]

set -euo pipefail

role_name="github-actions-deploy-role"
aws_region="us-west-2"
oidc_provider_arn=""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
  echo -e "${YELLOW}$1${NC}"
}

log_success() {
  echo -e "${GREEN}$1${NC}"
}

log_failure() {
  echo -e "${RED}$1${NC}"
}

exit_with_error() {
  log_failure "error: $1"
  exit 1
}

usage() {
  echo "Usage: $0 -a <aws_account_id> [-r <role_name>] [-w <aws_region>] [-p <oidc_provider_arn>]"
  exit 1
}

while getopts "a:r:w:p:" opt; do
  case ${opt} in
    a )
      aws_account_id=$OPTARG
      ;;
    r )
      role_name=$OPTARG
      ;;
    w )
      aws_region=$OPTARG
      ;;
    p )
      oidc_provider_arn=$OPTARG
      ;;
    \? )
      usage
      ;;
  esac
done

if [ -z "${aws_account_id:-}" ]; then
  exit_with_error "aws_account_id is a required argument."
fi

if [ -z "$oidc_provider_arn" ]; then
  oidc_provider_arn="arn:aws:iam::$aws_account_id:oidc-provider/token.actions.githubusercontent.com"
fi

log "fetching role arn..."
role_arn=$(aws iam get-role \
    --no-cli-pager \
    --role-name "$role_name" \
    --query "Role.Arn" \
    --output text \
    --region "$aws_region" || true)

if [ -n "$role_arn" ]; then
  log_success "role arn: $role_arn"
else
  exit_with_error "could not retrieve role arn."
fi

log "detaching policies from role '$role_name'..."
attached_policies=$(aws iam list-attached-role-policies \
    --no-cli-pager \
    --role-name "$role_name" \
    --query "AttachedPolicies[].PolicyArn" \
    --output text \
    --region "$aws_region")

if [ -n "$attached_policies" ]; then
  for policy_arn in $attached_policies; do
    log "detaching policy '$policy_arn' from role '$role_name'..."
    if aws iam detach-role-policy \
        --no-cli-pager \
        --role-name "$role_name" \
        --policy-arn "$policy_arn" \
        --region "$aws_region"; then
      log_success "policy '$policy_arn' detached successfully."
    else
      exit_with_error "failed to detach policy '$policy_arn' from role '$role_name'."
    fi
  done
else
  log "no policies attached to role '$role_name'."
fi

log "deleting the role '$role_name'..."
if aws iam delete-role --no-cli-pager --role-name "$role_name" --region "$aws_region"; then
  log_success "role '$role_name' deleted successfully."
else
  exit_with_error "failed to delete role '$role_name'."
fi

log "deleting OIDC provider '$oidc_provider_arn'..."
if aws iam delete-open-id-connect-provider \
    --no-cli-pager \
    --open-id-connect-provider-arn "$oidc_provider_arn" \
    --region "$aws_region"; then
  log_success "oidc provider '$oidc_provider_arn' deleted successfully."
else
  exit_with_error "failed to delete oidc provider '$oidc_provider_arn'."
fi
