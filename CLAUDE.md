# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo builds a Claude Code skill (packaged as a plugin) that replicates a layered Terraform style across future projects. The style is being refined as the skill is built, so expect the pattern to change. Suggest improvements as you go.

Layout: `.claude-plugin/plugin.json` is the plugin manifest and `skills/leszek-terraform-skill/SKILL.md` is the skill. Both are stubs for now.

`terraform/` holds sample code taken from another project (Azure, `azurerm ~> 5.0`). It is untracked reference material that will be refactored to the conventions below. It is not the deliverable. There are no tests, linter config or CI.

## Git and the sandbox

Git commands (`git init`, `git add`, `git commit`, etc.) are excluded from the Bash sandbox by command pattern. Run each one as a single, direct command. Do not chain them with `&&`, `;` or a `cd` prefix, and do not wrap them in `-C`, a subshell or a script, or they will not match the exclusion and will fail with "Operation not permitted" on `.git`. If the shell is not in the repo root, `cd` in a separate Bash call first. Make one commit per call.

## The pattern

- **Layers:** `terraform/layers/NN-name` are numbered, independent root modules, applied in order, each with its own state. Layers share no remote-state data sources. Their only coupling is shared names in the config file.
- **Config replaces tfvars:** one YAML file (`terraform/config/main.config.yml`) feeds every layer through `yamldecode`, so values are not duplicated across layers. `TF_VAR_environment` is the only Terraform variable.
- **Backend wiring:** each layer's `backend.tf` sets only the container and a per-layer state `key`. Subscription, resource group and storage account are injected at `init` through `TF_CLI_ARGS_init`, built in `terraform/set-env-config.sh`, which must be sourced.
- **Bootstrap:** the first layer (`00-tfbackend`) creates the storage that holds state for all layers, including its own. The sample has no bootstrap step, and the skill needs one.

## Agreed design changes (not yet implemented)

- **YAML shape:** top-level `global`, `tfbackend` and `layers` sections, not env at the top level. Where a value differs per environment, put an environment key (e.g. `DEV`) under the relevant layer or `tfbackend` key. The merged config is the plain keys plus that env's keys, one level deep only, so env names must be known to filter them out.
- **State:** one backend storage account per environment, so the environment is not part of the state key.
- **Backend values:** read from the YAML with `yq` in the scripts, not hardcoded in the shell script.
- **Credentials:** a service principal for deployments. Tenant, subscription and client values go in a gitignored `.env`, with a committed `.env.example`. Never commit real values.
- **Duplication:** no symlinks, for readability. Reduce copy-paste with a shared config module (`modules/config`) and by having the skill stamp a minimal `layer-base.tf` into each layer.
- **Naming:** underscores in Terraform resource labels, so names double-click-select. There is no rule for the Azure `name` values.
- **Cleanup:** remove commented-out code from the sample, and move hardcoded values such as vnet CIDRs into the config.

## Gotchas in the sample

- `layer-base.tf` is copy-pasted identically into each layer, so any change must be applied to every copy.
- azurerm v5 does not auto-register resource providers, so a new provider must be added to `resource_providers_to_register`.
- `set-env-config.sh` holds real tenant, subscription and client IDs. Do not copy them into docs or commits.
