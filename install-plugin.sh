#!/usr/bin/env bash
# Install or update leszek-terraform-plugin at user scope from the GitHub marketplace.
# Run it after pushing a plugin change, then restart Claude Code.
#
# `claude plugin install` only installs from a marketplace, and this repo is one
# (.claude-plugin/marketplace.json). The marketplace is added from its git remote, not from
# this checkout, so Claude Code clones it into its own cache and the installed plugin does not
# depend on this directory. Only pushed commits are installed. Installed plugins are cached by
# version, so bump "version" in plugin/.claude-plugin/plugin.json for an update to be picked up.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
marketplace="timdagit-marketplace"
source_url="git@github.com:timdagit/leszek-terraform-skill.git"
plugin="leszek-terraform-plugin"

command -v claude >/dev/null || { echo "claude CLI not found on PATH" >&2; exit 1; }

claude plugin validate "$root"
claude plugin validate "$root/plugin"

if claude plugin marketplace list | grep -q "$marketplace"; then
  claude plugin marketplace update "$marketplace"
else
  claude plugin marketplace add "$source_url"
fi

if claude plugin list | grep -q "$plugin@$marketplace"; then
  claude plugin update "$plugin@$marketplace"
else
  claude plugin install "$plugin@$marketplace" --scope user
fi

echo "Done. Restart Claude Code to load the changes."
