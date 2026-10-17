#!/usr/bin/env bash
# One-off bootstrap of the remote state storage for an environment:
#
#   scripts/bootstrap-backend.sh DEV
#
# 00-tfbackend creates the storage account that holds its own state, so the first apply has to
# use local state. This script applies it locally, then migrates the state into the new storage.
# Needs yq, terraform and credentials in .env (see set-env-config.sh). Prompts before applying.

set -euo pipefail

env="${1:?usage: scripts/bootstrap-backend.sh <ENVIRONMENT>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
layer="00-tfbackend"

# shellcheck disable=SC1091
. "$root/scripts/set-env-config.sh" "$env"

cd "$root/layers/$layer"

# A *_override.tf file swaps the backend block for local state while it exists.
override="backend_override.tf"
trap 'rm -f "$override"' EXIT
printf 'terraform {\n  backend "local" {}\n}\n' > "$override"

# The -backend-config flags in TF_CLI_ARGS_init do not apply to the local backend.
TF_CLI_ARGS_init="" terraform init -reconfigure
terraform apply

rm -f "$override"
terraform init -migrate-state -force-copy -backend-config="key=${layer}.tfstate"

echo "Bootstrapped $env. State for $layer now lives in the remote backend."
echo "The local terraform.tfstate files in $PWD are no longer needed."
