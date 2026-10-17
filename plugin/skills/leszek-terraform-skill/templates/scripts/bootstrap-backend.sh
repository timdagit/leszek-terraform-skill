#!/usr/bin/env bash
# One-off bootstrap of the remote state storage for an environment:
#
#   scripts/bootstrap-backend.sh DEV [layer]
#
# The backend layer (00-tfbackend, or 00-tfbackend-container when the storage account already
# exists) creates the storage that holds its own state, so the first apply has to use local
# state. This script applies it locally, then migrates the state into the new storage.
# The layer is the one directory matching layers/[0-9][0-9]-tfbackend*, or the name given.
# Needs yq, terraform and credentials in .env (see set-env-config.sh). Prompts before applying.
# Also needs the Azure CLI, logged in (`az login`) as someone who can create role assignments:
# the script grants the service principal Storage Blob Data Contributor on the state account.

set -euo pipefail

env="${1:?usage: scripts/bootstrap-backend.sh <ENVIRONMENT> [layer]}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -n "${2:-}" ]; then
  layer="$2"
else
  matches=()
  for dir in "$root"/layers/[0-9][0-9]-tfbackend*/; do
    [ -d "$dir" ] && matches+=("$(basename "$dir")")
  done
  if [ "${#matches[@]}" -ne 1 ]; then
    echo "Expected one layers/NN-tfbackend* directory, found ${#matches[@]}. Name the layer as the second argument." >&2
    exit 1
  fi
  layer="${matches[0]}"
fi
[ -d "$root/layers/$layer" ] || { echo "No such layer: $layer" >&2; exit 1; }

# shellcheck disable=SC1091
. "$root/scripts/set-env-config.sh" "$env"

# Check the Azure CLI up front: the role assignment comes after resources are created, so a missing
# login would otherwise only show up halfway through.
if ! command -v az >/dev/null; then
  echo "The Azure CLI (az) is required to grant the state storage role. Install it and run 'az login'." >&2
  exit 1
fi
if ! az account show --subscription "$ARM_SUBSCRIPTION_ID" >/dev/null 2>&1; then
  echo "Not logged in to Azure, or no access to subscription $ARM_SUBSCRIPTION_ID. Run 'az login' as someone who can create role assignments, then rerun." >&2
  exit 1
fi

cd "$root/layers/$layer"

# Leftover local state (e.g. from another environment's bootstrap) would be picked up as this one's.
if compgen -G "terraform.tfstate*" >/dev/null; then
  echo "Local state files found in $PWD. Remove or move them first, then rerun." >&2
  exit 1
fi

# A *_override.tf file swaps the backend block for local state while it exists.
override="backend_override.tf"
trap 'rm -f "$override"' EXIT
printf 'terraform {\n  backend "local" {}\n}\n' > "$override"

# The -backend-config flags in TF_CLI_ARGS_init do not apply to the local backend.
TF_CLI_ARGS_init="" terraform init -reconfigure
terraform apply

# State access is RBAC only, so the service principal needs Storage Blob Data Contributor on the
# account before it can read or write state. Contributor does not include blob data access.
# This needs an `az login` by someone allowed to create role assignments (Owner or User Access Administrator).
account_id="$(terraform output -raw storage_account_id)"
role="Storage Blob Data Contributor"
if [ -z "$(az role assignment list --subscription "$ARM_SUBSCRIPTION_ID" --assignee "$ARM_CLIENT_ID" --role "$role" --scope "$account_id" --query '[0].id' -o tsv)" ]; then
  echo "Granting '$role' to the service principal on $account_id"
  az role assignment create --subscription "$ARM_SUBSCRIPTION_ID" --assignee "$ARM_CLIENT_ID" \
    --assignee-principal-type ServicePrincipal --role "$role" --scope "$account_id" >/dev/null
fi

rm -f "$override"

# A new role assignment can take a few minutes to take effect, so retry the migration.
attempts=10
for ((i = 1; i <= attempts; i++)); do
  terraform init -migrate-state -force-copy -backend-config="key=${layer}.tfstate" && break
  if [ "$i" -eq "$attempts" ]; then
    echo "State migration failed after $attempts attempts. The local state is intact in $PWD." >&2
    exit 1
  fi
  echo "Retrying in 30s (role assignments can take a few minutes to propagate)..." >&2
  sleep 30
done

# The state is now remote. Clear the local copy so the next environment starts clean.
rm -f terraform.tfstate terraform.tfstate.backup

echo "Bootstrapped $env. State for $layer now lives in the remote backend."
