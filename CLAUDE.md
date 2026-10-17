# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo builds a Claude Code skill (packaged as a plugin) that replicates a layered Azure Terraform style across future projects. It is named for Leszek, who started the pattern. The style is still being refined, so expect it to change. Suggest improvements as you go, and do not add features until the user is happy with the template.

Layout:
- `plugin/` is the plugin, and the only thing copied into the install cache. Anything shipped must live under it. Repo-level files (`CLAUDE.md`, `README.md`, `install-plugin.sh`, `.idea`, `.claude`) stay outside it.
- `.claude-plugin/marketplace.json` (repo root) makes the repo a marketplace named `timdagit-marketplace`, with the plugin source `./plugin`. It is registered from the GitHub remote (`git@github.com:timdagit/leszek-terraform-skill.git`), never from this checkout as a `directory` source: Claude Code loads a directory-source plugin from the source directory and ignores the cache, so the skill's base directory pointed at the checkout and renaming it broke the plugin. Only pushed commits are installed, so push before running `install-plugin.sh`.
- `plugin/.claude-plugin/plugin.json` is the plugin manifest. Bump `version` in it when the plugin changes, because installed plugins are cached by version.
- `plugin/skills/leszek-terraform-skill/SKILL.md` is the skill. Its `description` drives auto-invocation, so change it with care. The body holds the conventions and the rules for what Claude runs and what the user runs.
- `plugin/skills/leszek-terraform-skill/templates/` is the deliverable: a working project skeleton (`config/`, `layers/00-tfbackend`, `layers/01-example`, `modules/config`, `scripts/`, `.env.example`, `README.md`).
- `README.md` at the repo root covers install and update. `templates/README.md` is the operating guide copied into generated projects.

The pattern came from sample code in another project, which has since been deleted from this repo. Never commit real tenant, subscription, client or secret values. There are no tests or CI. Check changes as described below.

## Git, Terraform and the sandbox

Git commands (`git init`, `git add`, `git commit`, etc.) are excluded from the Bash sandbox by command pattern. Run each one as a single, direct command. Do not chain them with `&&`, `;` or a `cd` prefix, and do not wrap them in `-C`, a subshell or a script, or they will not match the exclusion and will fail with "Operation not permitted" on `.git`. If the shell is not in the repo root, `cd` in a separate Bash call first. Make one commit per call.

`terraform init`, `terraform validate` and `terraform plan` are excluded the same way, so the same rule applies: run each as a single direct command with at least one flag, e.g. `terraform init -backend=false` and `terraform validate -no-color`. Do not chain them or use `-chdir`. `apply` and `destroy` are deliberately not excluded. `terraform fmt` needs no exclusion. Do not run `plan` against real infrastructure unless asked. `chmod` is denied, so give the user the command instead.

Do not run the scripts in `templates/scripts/` against real Azure. Test `set-env-config.sh` in a scratch copy with the placeholder `.env.example` values, and take care that `tfinit` there runs a real `terraform init`.

## Checking changes

- **Templates:** copy `plugin/skills/leszek-terraform-skill/templates` to a scratch directory inside the repo (e.g. `scratch-tpl/`), `cd` into a layer in its own Bash call, then run `terraform init -backend=false` and `terraform validate`. A `cd` outside the project does not persist. Delete the scratch directory afterwards and never commit it.
- **Scripts:** `shellcheck` all of them, and `bash -n` / `zsh -n` for syntax. `set-env-config.sh` needs `yq` (mikefarah v4).
- **Plugin:** `claude plugin validate .` checks the marketplace, and `claude plugin validate plugin` checks the plugin and skill.
- **Install:** `install-plugin.sh` is the user's to run, and has not been tested by Claude.

## The pattern

- **Layers:** `layers/NN-name` are numbered, independent root modules, applied in order, each with its own state. Layers share no remote-state data sources. Their only coupling is shared names in the config file.
- **One `terraform.tf` per layer:** identical in every layer. It holds the terraform block, `backend "azurerm" {}`, the `environment` variable, the `config` module call and the provider block. A change must be made in every layer's copy and in the template.
- **Config replaces tfvars:** one YAML file (`config/main.config.yml`) with `global`, `tfbackend` and `layers` sections. `modules/config` reads it and outputs `environment`, `global`, `tfbackend` and `layer`. A layer's block is keyed by the full directory name, number included (`layers.01-example`). A key named after an environment (listed in `global.environments`) is merged over the plain keys, one level deep. `TF_VAR_environment` is the only Terraform variable.
- **State:** each environment has its own backend storage account or container (`modules/config` rejects duplicates), so the environment is not in the state key. The key is the layer directory name. Access is Entra ID only (`use_azuread_auth=true` for the backend, `storage_use_azuread` in the provider block, `shared_access_key_enabled = false` on the account we create), never storage keys.
- **Backend wiring:** `scripts/set-env-config.sh` is sourced. It loads `.env`, exports `TF_VAR_environment`, reads the backend values from the YAML with `yq` and exports `TF_CLI_ARGS_init`. The `tfinit` function it defines adds the per-layer state key when run.
- **Credentials:** a service principal, with values in a gitignored `.env` (`.env.example` is committed). Never commit real values.
- **Bootstrap:** the backend layer creates the storage that holds all state, including its own. The templates ship two variants: `00-tfbackend` (new account and container) and `00-tfbackend-container` (container in an existing account). A project keeps one, or neither when the container exists already. `scripts/bootstrap-backend.sh <ENV> [layer]` finds the one `layers/NN-tfbackend*`, applies it with local state, grants the service principal Storage Blob Data Contributor on the account with `az` (the layer outputs `storage_account_id`; needs `az login` by someone who can assign roles), then migrates the state into the new storage, retrying while the role propagates.
- **Naming:** underscores in Terraform resource labels. No rule for Azure `name` values. No commented-out code, and hardcoded values such as CIDRs belong in the config.

## Known caveats

- azurerm v5 does not auto-register resource providers, so each new provider must be added to `global.resource_providers`.
- Verified by the user against real Azure: `bootstrap-backend.sh` with `00-tfbackend-container` (including the `az role assignment` step, the retry and RBAC-only state access), and the installed skill finding its templates.
- Not yet verified: `bootstrap-backend.sh` with `00-tfbackend` (new account), and the skill's auto-triggering.
- The templates do not ship `.terraform.lock.hcl`. Projects create it on first `init`.
- A per-environment subscription would need per-environment `.env` files. There is one `.env` for now.
