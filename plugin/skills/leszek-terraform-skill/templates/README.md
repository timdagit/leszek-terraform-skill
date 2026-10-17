# Terraform

Azure infrastructure as numbered, independent layers. Each layer is its own root module with its own state. One YAML file holds all configuration, and a sourced script sets up credentials and the remote backend.

```
config/main.config.yml   all configuration (replaces tfvars)
layers/NN-name/          one root module per layer, applied in numeric order
modules/config/          shared module that reads the YAML for a layer
scripts/                 set-env-config.sh, bootstrap-backend.sh
.env                     service principal credentials (gitignored, see .env.example)
```

## Prerequisites

- `terraform`, and `yq` ([mikefarah/yq](https://github.com/mikefarah/yq) v4, not the Python one)
- bash or zsh
- An Azure service principal with rights to create resources in the target subscription (Contributor is enough for the backend and the example layer)

## One-time setup

1. `cp .env.example .env` and fill in the service principal values. Never commit `.env`.
2. Edit `config/main.config.yml`. At minimum set `global.environments`, `global.location`, `global.tags`, and the `tfbackend` names. Storage account names are globally unique, lowercase and alphanumeric.

## Choose the backend layer

The templates ship two backend layers. Keep the one that fits and delete the other, since the bootstrap script expects exactly one `layers/NN-tfbackend*` directory:

| Situation | Keep | Creates |
|---|---|---|
| New storage for this project | `00-tfbackend` | resource group, storage account, container |
| Storage account already exists | `00-tfbackend-container` | container only |
| Account and container already exist | neither | nothing, no bootstrap needed |

In every case `tfbackend` in the config names the storage: `rg_name`, `storage_acct` and `container_name`, with per-environment overrides. Each environment needs its own storage account or container, because the state key does not include the environment (the config module rejects duplicates).

State access uses Entra ID (RBAC), never storage keys. `00-tfbackend` creates the account with shared keys disabled, and every layer's provider sets `storage_use_azuread`. The service principal needs Storage Blob Data Contributor on the storage account, which Contributor does not include. The bootstrap script grants it with the Azure CLI. For `00-tfbackend-container` the service principal also needs Contributor on the existing account to create the container. If you skip the bootstrap because the account and container already exist, grant Storage Blob Data Contributor yourself.

## Bootstrap the backend (once per environment)

The backend layer creates the storage that holds state for every layer, including its own. The first apply therefore has to use local state, and then the state moves into the new storage. The script does both:

```
scripts/bootstrap-backend.sh DEV
```

It needs the Azure CLI, logged in with `az login` as someone who can create role assignments (Owner or User Access Administrator) on the storage account. The script loads the environment, applies the backend layer with a temporary local backend (it prompts before applying), grants the service principal Storage Blob Data Contributor on the account if it lacks it, then migrates the state into the new storage. The migration retries for a few minutes, because a new role assignment takes time to propagate. It finds the layer by name (`layers/[0-9][0-9]-tfbackend*`), or takes it as a second argument. It refuses to run if local state files are already in the layer directory. Repeat with each environment name from `global.environments`.

## Everyday use

Source the environment script once per shell. It must be sourced, not executed:

```
source scripts/set-env-config.sh DEV
```

This loads `.env`, exports `TF_VAR_environment` (the only Terraform variable), and exports the backend settings read from the YAML. Then work in a layer:

```
cd layers/01-example
tfinit
terraform plan
terraform apply
```

`tfinit` is `terraform init` plus the state key, which is the layer directory name (`01-example.tfstate`). It works the key out each time it runs, so moving between layers is safe. A bare `terraform init` has no key and will prompt for one. Run `tfinit` again after changing environment or backend settings (add `-reconfigure`). To switch environment, source the script again with the other name.

Apply layers in numeric order. Layers share no remote state, so their only coupling is shared names in the config file.

## Configuration

`config/main.config.yml` has three top-level sections:

- `global`: settings shared by all layers (`environments`, `location`, `resource_providers`, `tags`)
- `tfbackend`: the remote state storage, read by the backend layer and by the scripts
- `layers`: one block per layer, keyed by the full directory name (`layers/01-example` reads `layers.01-example`)

Where a value differs per environment, add a key named after the environment inside the block. Its settings are merged over the plain ones, one level deep:

```yaml
layers:
  02-vnet:
    address_space: 10.0.0.0/16
    PROD:
      address_space: 10.1.0.0/16
```

Layers read their block through `module.config.layer`, and the shared sections through `module.config.global` and `module.config.tfbackend`. Using an environment that is not in `global.environments` fails the plan.

## Adding things

- **A layer:** copy an existing layer directory to `layers/NN-name`, keep `terraform.tf` unchanged, replace the resources, and add a `layers.NN-name` block to the config. Use the full name, number included.
- **An environment:** add it to `global.environments`, add its `tfbackend.<ENV>.storage_acct` (or `container_name` when sharing an account), then bootstrap it.
- **A resource provider:** azurerm v5 does not register providers automatically. Add the namespace to `global.resource_providers`.

## Conventions

- Underscores in Terraform resource labels, e.g. `azurerm_resource_group.app_network`. There is no rule for Azure `name` values.
- No commented-out code, and no hardcoded values that belong in the config.
- Commit `.terraform.lock.hcl` for each layer. Never commit `.env`, state files or `.terraform/`.
