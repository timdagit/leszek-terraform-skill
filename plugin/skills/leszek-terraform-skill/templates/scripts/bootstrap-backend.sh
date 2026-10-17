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

rm -f "$override"
terraform init -migrate-state -force-copy -backend-config="key=${layer}.tfstate"

# The state is now remote. Clear the local copy so the next environment starts clean.
rm -f terraform.tfstate terraform.tfstate.backup

echo "Bootstrapped $env. State for $layer now lives in the remote backend."
