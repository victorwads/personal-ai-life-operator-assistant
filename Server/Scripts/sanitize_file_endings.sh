#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"

find "$ROOT_DIR/Sources" "$ROOT_DIR/Resources" "$ROOT_DIR/Tests" "$ROOT_DIR/Scripts" -type f \
  \( -name '*.swift' -o -name '*.yml' -o -name '*.yaml' -o -name '*.md' -o -name '*.sh' -o -name '*.plist' \) \
  -print0 | while IFS= read -r -d '' file; do
    perl -0pi -e 's/\r\n/\n/g' "$file"
  done
