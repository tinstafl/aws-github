#!/bin/bash

# delete.sh -a <aws_account_id> -g <github_org> -r <repository_name> [-w <aws_region>] [-c <connection_name>]

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

log "fetching connection ARN for '$connection_name'..."

connection_arn=$(aws codestar-connections list-connections \
  --provider-type GitHub \
  --query "Connections[?ConnectionName=='$connection_name'].ConnectionArn" \
  --output text \
  --region "$aws_region")

if [ -z "$connection_arn" ]; then
  exit_with_error "could not find a CodeStar connection named '$connection_name'."
else
  log_success "found connection ARN: $connection_arn"
fi

log "deleting CodeStar connection '$connection_name'..."

if aws codestar-connections delete-connection \
  --connection-arn "$connection_arn" \
  --region "$aws_region"; then
  log_success "connection '$connection_name' deleted successfully."
else
  exit_with_error "failed to delete connection '$connection_name'."
fi
