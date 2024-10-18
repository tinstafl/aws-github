#!/bin/bash

# extend.sh -r <aws_region> -n <role_name> -o <github_org> -p <repository_name>

set -euo pipefail

aws_region=""
role_name=""
github_org=""
repository_name=""

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
  echo "Usage: $0 -r <aws_region> -n <role_name> -o <github_org> -p <repository_name>"
  exit 1
}

while getopts "r:n:o:p:" opt; do
  case ${opt} in
    r )
      aws_region=$OPTARG
      ;;
    n )
      role_name=$OPTARG
      ;;
    o )
      github_org=$OPTARG
      ;;
    p )
      repository_name=$OPTARG
      ;;
    \? )
      usage
      ;;
  esac
done

if [ -z "${aws_region:-}" ] || [ -z "${role_name:-}" ] || [ -z "${github_org:-}" ] || [ -z "${repository_name:-}" ]; then
  exit_with_error "All parameters -r <aws_region>, -n <role_name>, -o <github_org>, and -p <repository_name> are required."
fi

log "retrieving existing role trust policy for role '$role_name' in region '$aws_region'..."

existing_trust_policy=$(aws iam get-role \
    --no-cli-pager \
    --role-name "$role_name" \
    --query "Role.AssumeRolePolicyDocument" \
    --output json \
    --region "$aws_region" || exit_with_error "failed to retrieve trust policy")

log "updating trust policy to include 'repo:$github_org/$repository_name'..."

current_condition=$(jq -c ".Statement[].Condition.StringLike.\"token.actions.githubusercontent.com:sub\"" <<< "$existing_trust_policy")

new_condition="repo:$github_org/$repository_name:*"

updated_condition=()

if [[ "$current_condition" =~ ^\[\s* ]]; then
  while IFS= read -r line; do
    updated_condition+=("$line")
  done < <(echo "$current_condition" | jq -r '.[]')
else
  if [[ -n "$current_condition" ]]; then
    updated_condition=("${current_condition//\"/}")
  fi
fi

exists=false
for condition in "${updated_condition[@]}"; do
  if [[ "$condition" == "$new_condition" ]]; then
    exists=true
    break
  fi
done

if ! $exists; then
  updated_condition+=("$new_condition")
fi

updated_condition_json=$(printf '%s\n' "${updated_condition[@]}" | jq -R . | jq -s .)

new_trust_policy=$(jq --argjson updated_condition "$updated_condition_json" \
  '.Statement[].Condition.StringLike."token.actions.githubusercontent.com:sub" = $updated_condition' <<< "$existing_trust_policy")

log "updating trust policy in IAM for role '$role_name'..."

if aws iam update-assume-role-policy \
    --no-cli-pager \
    --role-name "$role_name" \
    --policy-document "$new_trust_policy" \
    --region "$aws_region"; then
  log_success "trust policy updated successfully to include 'repo:$github_org/$repository_name'."
else
  exit_with_error "failed to update the trust policy."
fi
