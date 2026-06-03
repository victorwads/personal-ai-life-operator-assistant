#!/usr/bin/env bash

FORBIDDEN_MODEL_METADATA_TERMS=(
  "createdAt"
  "updatedAt"
  "deletedAt"
)

check_forbidden_model_metadata() {
  if [[ ! -d "$SOURCES_DIR" ]]; then
    return 0
  fi

  local model_file
  while IFS= read -r model_file; do
    [[ -z "$model_file" ]] && continue

    local relative_file
    relative_file="$(repo_relative_path "$model_file")"

    local term
    for term in "${FORBIDDEN_MODEL_METADATA_TERMS[@]}"; do
      local matches
      matches="$(grep -n -F -- "$term" "$model_file" || true)"

      if [[ -n "$matches" ]]; then
        add_error "$(cat <<EOF
Generic Firebase audit metadata must not live in domain models.
FirestoreRepository injects createdAt, updatedAt, and deletedAt into Firestore payloads.
Remove this field from the model unless it is a real domain timestamp with a more specific name.
  File: $relative_file
  Matched term: $term
$(echo "$matches" | sed 's/^/  Line: /')
EOF
)"
      fi
    done
  done < <(find "$SOURCES_DIR" -type f -path '*/Models/*.swift' ! -path "$SOURCES_DIR/Infrastructure/Firebase/*")
}

register_linter "Forbidden model metadata" check_forbidden_model_metadata
