#!/usr/bin/env bash
# Install or update leszek-terraform-plugin at user scope from this checkout.
# Run it after pulling or editing the plugin, then restart Claude Code.
#
# `claude plugin install` only installs from a marketplace, so this repo doubles as a
# local marketplace (.claude-plugin/marketplace.json). Only plugin/ is the plugin, so
# only its contents are copied into the cache, and the installed plugin does not depend on
# this checkout. Installed plugins are cached by version, so bump "version" in
# plugin/.claude-plugin/plugin.json for an update to be picked up.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
marketplace="local-marketplace"
plugin="leszek-terraform-plugin"

command -v claude >/dev/null || { echo "claude CLI not found on PATH" >&2; exit 1; }

claude plugin validate "$root"
claude plugin validate "$root/plugin"

if claude plugin marketplace list | grep -q "$marketplace"; then
  claude plugin marketplace update "$marketplace"
else
  claude plugin marketplace add "$root"
fi

if claude plugin list | grep -q "$plugin@$marketplace"; then
  claude plugin update "$plugin@$marketplace"
else
  claude plugin install "$plugin@$marketplace" --scope user
fi

echo "Done. Restart Claude Code to load the changes."
