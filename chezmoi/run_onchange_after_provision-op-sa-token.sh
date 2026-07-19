#!/bin/sh
# Provision the claude-automation Service Account token to ~/.config/op/claude-sa-token
# (source of truth: 1Password item "claude-sa-token" in the Personal vault).
# New-machine bootstrap: runs after `op signin`; skips gracefully when op isn't ready
# so a fresh `chezmoi apply` never hard-fails on ordering.
# Token rotation is manual — rotate on 1Password.com, update the item, then rerun:
#   op read --out-file ~/.config/op/claude-sa-token "op://Personal/claude-sa-token/credential" && chmod 600 ~/.config/op/claude-sa-token
set -eu

TOKEN_FILE="$HOME/.config/op/claude-sa-token"

# Already provisioned — rotation is manual (see header), never overwrite here.
if [ -s "$TOKEN_FILE" ]; then
  exit 0
fi

# Guard must be non-interactive: `op account get` with no account opens /dev/tty
# and prompts "add an account manually? [Y/n]" even with stdout/stderr redirected
# (stdin </dev/null does NOT prevent it — measured on Tart VM 2026-07-19), which
# deadlocks unattended runs (install.sh). `op whoami` fails fast without prompting.
if ! command -v op >/dev/null 2>&1 || ! op whoami >/dev/null 2>&1; then
  echo "op-sa provisioning: op not available/signed in yet — skipping (rerun chezmoi apply after op signin)" >&2
  exit 0
fi

mkdir -p "$HOME/.config/op"
umask 077
if op read --out-file "$TOKEN_FILE" "op://Personal/claude-sa-token/credential" >/dev/null 2>&1; then
  chmod 600 "$TOKEN_FILE"
  echo "op-sa provisioning: token written to $TOKEN_FILE" >&2
else
  echo "op-sa provisioning: item claude-sa-token not found in Personal vault — skipping" >&2
fi
