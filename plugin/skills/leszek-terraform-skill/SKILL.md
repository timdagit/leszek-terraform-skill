---
name: leszek-terraform-skill
description: Scaffold, extend and review layered Azure Terraform projects. Numbered root-module layers (00-tfbackend, 01-..., 02-...) are driven by one YAML config file instead of tfvars, with one backend storage account per environment and a sourced env script for ARM credentials. Use by default for all new Terraform projects and when maintaining existing ones, unless the user says otherwise. In an existing repo that is not laid out this way, follow its current structure and do not restructure it unless asked. Triggers: starting a Terraform project or layer, adding resources or config, setting up an azurerm backend, or working with .tf files, terraform init/plan/apply, or main.config.yml.
---

# leszek-terraform-skill

A layered Azure Terraform style, started by Leszek. The `templates/` directory next to this file is a working project skeleton. Copy from it instead of writing the harness from memory, and keep the copies identical. Take it from this skill's own base directory (the path given when the skill loads, inside the installed plugin). Never search for another copy, such as a plugin source checkout or marketplace directory, because those can be stale or missing.

## When it applies

- **New project:** scaffold from `templates/`.
- **Existing project in this layout:** follow the conventions below.
- **Existing project in another layout:** leave its structure alone unless asked. Offer this skill's approach only if the user wants to migrate.

## Project layout

Scaffold into the project's Terraform directory (the sample uses `terraform/`):

```
config/main.config.yml   all configuration
layers/NN-name/          one root module per layer
modules/config/          shared config reader
scripts/                 set-env-config.sh, bootstrap-backend.sh
.env.example             committed. .env is gitignored
README.md                the operating guide for humans
```

Copy `templates/` for these, then replace the example layer and the placeholder names in the config (project name, storage account names, `created_by`). Add `.env`, `.terraform/`, `*.tfstate*` and `*.tfplan` to `.gitignore`.

**Choose the backend layer first.** Ask the user which case applies, then keep one backend layer and delete the other (the bootstrap script expects exactly one `layers/NN-tfbackend*`):

- New storage for the project: keep `00-tfbackend` (resource group, storage account, container).
- Existing storage account, new container: keep `00-tfbackend-container` (container only).
- Existing account and container: keep neither and skip the bootstrap. Just set the `tfbackend` names in the config. Start the other layers at `01`.

## Conventions

- **Layers:** `NN-name`, numbered in apply order, each an independent root module with its own state. Layers never read each other's remote state. Their only coupling is names in the config file.
- **`terraform.tf`:** identical in every layer. It holds the terraform block (azurerm `~> 5.0`, `backend "azurerm" {}`), the `environment` variable, the `config` module call and the provider block. Do not edit it per layer. If it must change, change every layer's copy and the template. Resources go in other files named for what they hold (`vnet.tf`, `example.tf`).
- **Config:** one YAML file, `global`, `tfbackend` and `layers` sections. A layer's block is keyed by its full directory name, number included (`layers/02-vnet` reads `layers.02-vnet`). Layers read it through `module.config.layer`, `.global` and `.tfbackend`, never with their own `yamldecode`. `TF_VAR_environment` is the only Terraform variable.
- **Environment differences:** an environment-named key (e.g. `PROD`) inside a block, merged over the plain keys, one level deep. Every environment must be listed in `global.environments`.
- **No hardcoded values:** CIDRs, names, SKUs and counts belong in the config. Give optional settings defaults with `try()`.
- **Naming:** underscores in Terraform resource labels. No rule for Azure `name` values.
- **State:** each environment has its own backend storage account or container, so the environment is not in the state key. The key is the layer directory name. Access is Entra ID (RBAC) only, never storage keys.
- **Providers:** azurerm v5 does not register resource providers. Add each needed namespace to `global.resource_providers`.
- **Clean code:** no commented-out code. Remove it rather than leave it.
- **Secrets:** never put credentials in config, code or docs. They live only in `.env`. `TF_VAR_environment` is the only Terraform variable for now, but the same route can carry secrets or passwords later: add a `TF_VAR_<name>` to `.env` (and `.env.example` with a placeholder), declare a `sensitive` variable in the layers that need it, and keep the value out of the YAML. Only do this when a layer needs it, and tell the user the `terraform.tf` copies and the template must change together.

## Adding a layer

Copy the example layer to `layers/NN-name`, use the next free number, keep `terraform.tf` as is, replace the resources, and add a `layers.NN-name` block to the config. Add any new resource providers to `global.resource_providers`.

## Updating a project after the plugin changes

`templates/README.md` is a generic guide. Once it has been copied into a project and customised, it belongs to that project. Never overwrite it, or any other customised file, from a newer copy of the templates. Only edit in place the sections that describe the plugin (for example the scripts, `tfinit` or the bootstrap) and only when the plugin's behaviour has changed. Leave the project's own content alone. Show the user what you propose to change first.

## Operating it: who runs what

Operations are in the project's `README.md` (copied from `templates/README.md`): bootstrap the backend with `scripts/bootstrap-backend.sh <ENV>`, then per shell `source scripts/set-env-config.sh <ENV>`, and per layer `tfinit`, `terraform plan`, `terraform apply`. Point the user to it rather than restating it.

`tfinit` is a function defined by sourcing `set-env-config.sh`, so it does not exist in a new shell or tab. Without the source, `terraform init` and `plan` fail or prompt, because `TF_VAR_environment` and the backend settings are missing.

When driving from Claude Code, the split matters:

- **Do yourself:** write code and config, `terraform fmt`, `terraform init -backend=false`, `terraform validate`. Run each as a single direct command so the sandbox exclusions match (no chaining, no `-chdir`).
- **Hand to the user:** sourcing `set-env-config.sh`, `tfinit`, `plan`, `apply`, `destroy` and the bootstrap. They need `.env` credentials, which you must not read, and shell state from `source` does not persist between your commands. Give the exact commands and say they should run them in their own terminal. Always give the `source scripts/set-env-config.sh <ENV>` line together with `tfinit`, never `tfinit` on its own.
- **Never** read, print or echo `.env` or any `ARM_*` value, and never run `apply` or `destroy` unasked.

## Checking a change

After editing layers or the config module: `terraform fmt -check -recursive`, then in each affected layer `terraform init -backend=false` and `terraform validate`. The config module's environment check fires on every plan, so an unlisted environment fails early. After a template change, also validate a scratch copy of `templates/` outside the user's project.
