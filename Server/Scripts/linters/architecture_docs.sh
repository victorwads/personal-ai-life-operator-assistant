#!/usr/bin/env bash

check_source_architecture_docs_are_linked() {
  if [[ ! -f "$DOCS_ARCHITECTURE" ]]; then
    add_error "Docs/Architecture.md does not exist at $DOCS_ARCHITECTURE"
    return
  fi

  if [[ ! -d "$SOURCES_DIR" ]]; then
    return
  fi

  local architecture_file
  while IFS= read -r architecture_file; do
    [[ -z "$architecture_file" ]] && continue

    local basename
    basename="$(basename "$architecture_file")"

    local relative_path
    relative_path="$(repo_relative_path "$architecture_file")"

    if [[ "$basename" != "Architecture.md" ]]; then
      add_error "Architecture docs must be named exactly Architecture.md.
  Invalid file: $relative_path
  Rename this file to Architecture.md inside its owning folder.
  Do not use names like FirebaseArchitecture.md, architecture.md, ARCHITECTURE.md, or FeatureArchitecture.md."
      continue
    fi

    if ! grep -Fq "$relative_path" "$DOCS_ARCHITECTURE"; then
      add_error "Source architecture doc is not linked from Docs/Architecture.md.
  Missing path: $relative_path
  Add this repo-relative path to Docs/Architecture.md."
    fi
  done < <(find "$SOURCES_DIR" -type f -iname '*architecture*.md')
}

register_linter "Architecture docs linked" check_source_architecture_docs_are_linked
