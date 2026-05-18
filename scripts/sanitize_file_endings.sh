#!/bin/sh

set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

swift_file_count=0
fixed_count=0

# Only touch files that are missing the final LF byte.
while IFS= read -r file; do
  swift_file_count=$((swift_file_count + 1))

  # Empty files are considered "sanitized" (they end with nothing).
  if [ ! -s "$file" ]; then
    continue
  fi

  # Read the last byte as an unsigned integer. `10` means LF.
  last_byte="$(tail -c 1 "$file" | od -An -tu1 | tr -d '[:space:]')"
  if [ "$last_byte" != "10" ]; then
    printf '\n' >>"$file"
    fixed_count=$((fixed_count + 1))
  fi
done <<EOF
$(find "$REPO_DIR/Sources" -type f -name "*.swift" -print)
EOF

echo "sanitize_file_endings: scanned=$swift_file_count fixed=$fixed_count"

