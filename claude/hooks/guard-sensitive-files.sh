#!/usr/bin/env bash
# PreToolUse hook (Edit|Write): block agent edits to files that hold
# secrets or that should never be edited by hand.
#
#   secrets      .env and variants, private keys, credential stores
#   generated    dependency lockfiles (regenerate with the tool instead)
#   internals    anything under .git/
#
# Exit 2 blocks. Fails closed when jq is missing.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Blocked: jq missing (guard-sensitive-files.sh cannot inspect the path)" >&2
  exit 2
fi

FILE=$(jq -r '.tool_input.file_path // ""')
[ -z "$FILE" ] && exit 0

BASE=$(basename "$FILE")

deny() { echo "Blocked: $1 ($FILE)" >&2; exit 2; }

case "$BASE" in
  .env|.env.*)                       deny "environment file with secrets" ;;
  *.pem|*.key|*.p12|*.pfx)           deny "private key material" ;;
  id_rsa*|id_ecdsa*|id_ed25519*)     deny "ssh private key" ;;
  .netrc|.pgpass)                    deny "credential store" ;;
  package-lock.json|yarn.lock|pnpm-lock.yaml|bun.lockb) deny "lockfile: regenerate via the package manager" ;;
  Cargo.lock|poetry.lock|uv.lock|Gemfile.lock|composer.lock|flake.lock) deny "lockfile: regenerate via the package manager" ;;
esac

case "$FILE" in
  */.git/*|.git/*)                   deny "git internals" ;;
  */.aws/credentials|*/.ssh/*)       deny "credential store" ;;
esac

exit 0
