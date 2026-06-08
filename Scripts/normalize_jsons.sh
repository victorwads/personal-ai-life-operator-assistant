#!/bin/sh

find Server/Tests -name "*.json" -type f -exec sh -c '
  for file do
    jq . "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  done
' sh {} +
