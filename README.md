# leszek-terraform-plugin

A Claude Code plugin that provides `leszek-terraform-skill`, a layered, YAML-configured style for Azure Terraform projects. Hat tip to Leszek, who started the pattern.

## What it does

The skill teaches Claude Code to scaffold and maintain Terraform projects as numbered, independent layers, each with its own state. One YAML file replaces tfvars, a sourced script sets credentials and the remote backend, and there is one state storage account per environment. It is used by default for new Terraform projects and for maintaining existing ones in this layout, unless you say otherwise.

The skill ships a working project skeleton in `plugin/skills/leszek-terraform-skill/templates/`. Its `README.md` is the operating guide that gets copied into each new project, covering backend bootstrap and everyday layer work.

## Install and update

Needs the `claude` CLI and SSH access to GitHub. Without a checkout:

```
claude plugin marketplace add git@github.com:timdagit/leszek-terraform-skill.git
claude plugin install leszek-terraform-plugin@timdagit-marketplace --scope user
```

Or from a checkout of this repo, which does both and also updates:

```
./install-plugin.sh
```

The repo is a marketplace served from its GitHub remote. Claude Code clones it into its own cache, so the installed plugin does not depend on any local checkout, and only pushed commits are installed. Restart Claude Code afterwards. Installed plugins are cached by version, so bump `version` in `plugin/.claude-plugin/plugin.json` when you change the plugin, push, then rerun the script.

Do not register a local checkout as a `directory` marketplace. Claude Code then loads the plugin from that directory instead of its cache, so edits are live and renaming or deleting the checkout breaks the plugin.

## Repo layout

```
.claude-plugin/marketplace.json          marketplace definition, served from the GitHub remote
plugin/.claude-plugin/plugin.json        plugin manifest
plugin/skills/leszek-terraform-skill/    SKILL.md and the templates it copies from
install-plugin.sh                        install or update the plugin
```

## Developing

To check template changes, copy `plugin/skills/leszek-terraform-skill/templates` to a scratch directory, then run `terraform init -backend=false` and `terraform validate` in each layer. Lint the scripts with `shellcheck`. `claude plugin validate .` checks the marketplace and `claude plugin validate plugin` checks the plugin and skill.
