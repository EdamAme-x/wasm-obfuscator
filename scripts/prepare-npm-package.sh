#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

moon_cmd="${MOON:-$HOME/.moon/bin/moon}"
if [[ ! -x "$moon_cmd" ]]; then
  if command -v moon >/dev/null 2>&1; then
    moon_cmd="moon"
  else
    echo "moon command not found" >&2
    exit 1
  fi
fi

"$moon_cmd" build cmd/main --target js --release

SKIP_MOON_BUILD=1 node scripts/generate-browser-module.mjs npm/browser.mjs

mkdir -p npm/dist
{
  echo '#!/usr/bin/env node'
  cat _build/js/release/build/cmd/main/main.js
} > npm/dist/cli.js
chmod +x npm/dist/cli.js

echo "prepared npm/dist/cli.js and npm/browser.mjs"
