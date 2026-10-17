# leszek-terraform-plugin

A Claude Code plugin that provides `leszek-terraform-skill`, a layered, YAML-configured style for Azure Terraform projects. Hat tip to Leszek, who started the pattern.

## What it does

The skill teaches Claude Code to scaffold and maintain Terraform projects as numbered, independent layers, each with its own state. One YAML file replaces tfvars, a sourced script sets credentials and the remote backend, and there is one state storage account per environment. It is used by default for new Terraform projects and for maintaining existing ones in this layout, unless you say otherwise.

The skill ships a working project skeleton in `plugin/skills/leszek-terraform-skill/templates/`. Its `README.md` is the operating guide that gets copied into each new project, covering backend bootstrap and everyday layer work.

## Install and update

Needs the `claude` CLI. From a checkout of this repo:

```
./install-plugin.sh
```

This registers the repo as a local marketplace and installs or updates the plugin at user scope. Only the `plugin/` directory is copied into Claude Code's cache, so the installed plugin is self-contained and keeps working if this checkout moves or is deleted (only updating needs the checkout, and a moved checkout must be re-registered by rerunning the script after `claude plugin marketplace remove local-marketplace`). Restart Claude Code afterwards. Installed plugins are cached by version, so bump `version` in `plugin/.claude-plugin/plugin.json` when you change the plugin, then rerun the script.

## Repo layout

```
.claude-plugin/marketplace.json          local marketplace used by the installer
plugin/.claude-plugin/plugin.json        plugin manifest
plugin/skills/leszek-terraform-skill/    SKILL.md and the templates it copies from
install-plugin.sh                        install or update the plugin
```

## Developing

To check template changes, copy `plugin/skills/leszek-terraform-skill/templates` to a scratch directory, then run `terraform init -backend=false` and `terraform validate` in each layer. Lint the scripts with `shellcheck`. `claude plugin validate .` checks the marketplace and `claude plugin validate plugin` checks the plugin and skill.
