#!/bin/bash

# create.sh -a <aws_account_id> -g <github_org> -r <repository_name> [-w <aws_region>] [-c <connection_name>]

set -euo pipefail

aws_region="us-west-2"
connection_name="github-codeconnection"

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
  echo "Usage: $0 -a <aws_account_id> -g <github_org> -r <repository_name> [-w <aws_region>] [-c <connection_name>]"
  exit 1
}

while getopts "a:g:r:w:c:" opt; do
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
    w )
      aws_region=$OPTARG
      ;;
    c )
      connection_name=$OPTARG
      ;;
    \? )
      usage
      ;;
  esac
done

if [ -z "${aws_account_id:-}" ] || [ -z "${github_org:-}" ] || [ -z "${repository_name:-}" ]; then
  exit_with_error "aws_account_id, github_org, and repository_name are required arguments."
fi

log "creating CodeStar connection '$connection_name'..."

connection_arn=$(aws codestar-connections create-connection \
  --provider-type GitHub \
  --connection-name "$connection_name" \
  --region "$aws_region" \
  --query "ConnectionArn" \
  --output text)

if [ -n "$connection_arn" ]; then
  log_success "connection '$connection_name' created successfully with ARN: $connection_arn"
else
  exit_with_error "failed to create CodeStar connection."
fi

log "checking the CodeStar connection status..."

connection_status=$(aws codestar-connections get-connection \
  --connection-arn "$connection_arn" \
  --region "$aws_region" \
  --query "Connection.ConnectionStatus" \
  --output text)

if [ "$connection_status" == "AVAILABLE" ]; then
  log_success "connection '$connection_name' is active and authorized."
elif [ "$connection_status" == "PENDING" ]; then
  log_failure "connection is in PENDING state. Please authorize it in the AWS Management Console."
  exit_with_error "Manual authorization required."
else
  exit_with_error "failed to authorize connection. Status: $connection_status"
fi
