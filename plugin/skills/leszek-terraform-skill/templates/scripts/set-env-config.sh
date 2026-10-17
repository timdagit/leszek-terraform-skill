#!/usr/bin/env bash
# Prepare the shell for Terraform. Source it, do not execute it (bash or zsh):
#
#   source scripts/set-env-config.sh DEV
#   cd layers/01-example
#   tfinit            # terraform init with this layer's state key
#   terraform plan
#
# - Loads credentials (ARM_*) from .env next to the scripts directory (see .env.example).
# - Exports TF_VAR_environment, the only Terraform variable.
# - Reads the backend resource group, storage account and container from config/main.config.yml
#   with yq (mikefarah/yq v4) and exports them as TF_CLI_ARGS_init. State access uses Entra ID
#   (RBAC), never storage keys, so the service principal needs Storage Blob Data Contributor
#   on the storage account or container.
# - Defines tfinit, which adds the state key (the layer directory name, e.g. 01-example.tfstate).
#   The key is worked out when tfinit runs, so changing directory can never point a layer at
#   another layer's state. A bare "terraform init" has no key and will prompt for one.

# $1 script path, $2 environment name
_set_env_config() {
  local script="$1" env="$2" root config name

  root="$(cd "$(dirname "$script")/.." && pwd)" || return 1
  config="$root/config/main.config.yml"

  if [ -z "$env" ]; then
    echo "usage: source scripts/set-env-config.sh <ENVIRONMENT>" >&2
    return 1
  fi
  command -v yq >/dev/null || { echo "yq not found (https://github.com/mikefarah/yq)" >&2; return 1; }
  [ -f "$config" ] || { echo "config not found: $config" >&2; return 1; }

  ENV_NAME="$env" yq -e '.global.environments[] | select(. == strenv(ENV_NAME))' "$config" >/dev/null 2>&1 \
    || { echo "$env is not listed in global.environments in $config" >&2; return 1; }

  if [ -f "$root/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$root/.env"
    set +a
  else
    echo "warning: $root/.env not found, copy .env.example to .env" >&2
  fi
  for name in ARM_TENANT_ID ARM_SUBSCRIPTION_ID ARM_CLIENT_ID ARM_CLIENT_SECRET; do
    eval "[ -n \"\${$name:-}\" ]" || echo "warning: $name is not set" >&2
  done

  local rg_name storage_acct container_name
  rg_name="$(_set_env_config_get "$config" "$env" rg_name)" || return 1
  storage_acct="$(_set_env_config_get "$config" "$env" storage_acct)" || return 1
  container_name="$(_set_env_config_get "$config" "$env" container_name)" || return 1

  export TF_VAR_environment="$env"
  export TF_CLI_ARGS_init="-backend-config=subscription_id=${ARM_SUBSCRIPTION_ID:-} -backend-config=resource_group_name=${rg_name} -backend-config=storage_account_name=${storage_acct} -backend-config=container_name=${container_name} -backend-config=use_azuread_auth=true"

  echo "environment: $env  backend: $storage_acct ($rg_name/$container_name)"
}

# $1 config file, $2 environment, $3 tfbackend key. The environment's value wins over the plain one.
_set_env_config_get() {
  local value
  value="$(ENV_NAME="$2" yq ".tfbackend[strenv(ENV_NAME)].$3 // .tfbackend.$3" "$1")"
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "tfbackend.$3 is not set for $2 in $1" >&2
    return 1
  fi
  printf '%s\n' "$value"
}

tfinit() {
  local layer
  layer="$(basename "$PWD")"
  case "$layer" in
    [0-9][0-9]-*) ;;
    *) echo "tfinit: run it from a layers/NN-name directory" >&2; return 1 ;;
  esac
  terraform init -backend-config="key=${layer}.tfstate" "$@"
}

# BASH_SOURCE is empty in zsh, where $0 is the sourced file.
_set_env_config "${BASH_SOURCE[0]:-$0}" "${1:-}"
_sec_status=$?
unset -f _set_env_config _set_env_config_get
# Return when sourced. Executing the script does nothing useful, so say so.
# shellcheck disable=SC2317
return "$_sec_status" 2>/dev/null || { echo "source this script, do not execute it" >&2; exit 1; }
