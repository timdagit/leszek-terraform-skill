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

## Not done yet

Ideas that came up and were deferred until the template has been used on a real project:

- **Resume mode for the bootstrap.** If `bootstrap-backend.sh` fails after the apply, for example when the state migration times out, recovery is manual. Re-run `terraform init -migrate-state` by hand in the backend layer. A flag to skip straight to the role grant and migration would make this safer.
- **Early check for role-assignment rights.** The script checks the Azure CLI login but not that the logged-in user can create role assignments, so a missing right only shows up after the storage is created.
- **Cross-subscription backends.** There is one subscription and one `.env`. Keeping state in a different subscription from the resources, or one subscription per environment, would need per-environment `.env` files and a subscription per `tfbackend` entry.
- **Backend layer choice.** Both `00-tfbackend` and `00-tfbackend-container` ship, so a scaffolded project has to delete one. A single backend layer that creates the account only when asked would remove that step.

## Developing

To check template changes, copy `plugin/skills/leszek-terraform-skill/templates` to a scratch directory, then run `terraform init -backend=false` and `terraform validate` in each layer. Lint the scripts with `shellcheck`. `claude plugin validate .` checks the marketplace and `claude plugin validate plugin` checks the plugin and skill.
