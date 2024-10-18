#!/bin/bash

# create.sh -a <aws_account_id> -g <github_org> -r <repository_name> [-o <oidc_audience>] [-n <role_name>] [-p <oidc_provider_arn>] [-w <aws_region>]

set -euo pipefail

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

role_name="github-actions-operator-role"
oidc_audience="sts.amazonaws.com"
aws_region="us-west-2"
oidc_provider_arn=""

usage() {
  echo "Usage: $0 -a <aws_account_id> -g <github_org> -r <repository_name> [-o <oidc_audience>] [-n <role_name>] [-p <oidc_provider_arn>] [-w <aws_region>]"
  exit 1
}

while getopts "a:g:r:o:n:p:w:" opt; do
  case ${opt} in
    a )
      aws_account_id=$OPTARG
      ;;
    g )
      github_org=$OPTARG
      ;;
    r )
      repository_name=$OPTARG
      ;;
    o )
      oidc_audience=$OPTARG
      ;;
    n )
      role_name=$OPTARG
      ;;
    p )
      oidc_provider_arn=$OPTARG
      ;;
    w )
      aws_region=$OPTARG
      ;;
    \? )
      usage
      ;;
  esac
done

if [ -z "${aws_account_id:-}" ] || [ -z "${github_org:-}" ] || [ -z "${repository_name:-}" ]; then
  exit_with_error "aws_account_id, github_org, and repository_name are required arguments."
fi

if [ -z "$oidc_provider_arn" ]; then
  oidc_provider_arn="arn:aws:iam::$aws_account_id:oidc-provider/token.actions.githubusercontent.com"
fi

trust_policy=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Principal": {
        "Federated": "$oidc_provider_arn"
      },
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "$oidc_audience"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:$github_org/$repository_name:*"
          ]
        }
      }
    }
  ]
}
EOF
)

log "creating oidc identity provider for github organization..."

if aws iam create-open-id-connect-provider \
    --no-cli-pager \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
    --region "$aws_region"; then
  log_success "oidc identity provider created successfully."
else
  exit_with_error "failed to create oidc identity provider."
fi

log "creating iam role for github organization oidc provider..."

if aws iam create-role --no-cli-pager --role-name "$role_name" --assume-role-policy-document "$trust_policy" --region "$aws_region"; then
  log_success "role $role_name created successfully"
else
  exit_with_error "failed to create role $role_name"
fi

log "attaching role policies to github organization oidc provider role..."

if aws iam attach-role-policy --no-cli-pager --role-name "$role_name" --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" --region "$aws_region"; then
  log_success "policy attached to role $role_name"
else
  exit_with_error "failed to attach policy to role $role_name"
fi
