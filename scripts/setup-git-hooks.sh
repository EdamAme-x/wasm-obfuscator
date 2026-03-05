#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ! -d .githooks ]]; then
  echo "Error: .githooks directory not found."
  exit 1
fi

chmod +x .githooks/pre-commit .githooks/pre-push
git config core.hooksPath .githooks

echo "Git hooks are enabled via core.hooksPath=.githooks"
echo "To bypass once: SKIP_MOON_HOOKS=1 git commit -m '...'"
