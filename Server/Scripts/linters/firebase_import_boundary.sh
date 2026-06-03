#!/usr/bin/env bash

FIREBASE_IMPORT_BOUNDARY_TERMS=(
  "import Firebase"
  "import FirebaseAuth"
  "import FirebaseCore"
  "import FirebaseFirestore"
  "import FirebaseStorage"
  "FirebaseApp"
  "FirebaseFirestore"
  "Firestore"
  "CollectionReference"
  "DocumentReference"
  "DocumentSnapshot"
  "QuerySnapshot"
  "ListenerRegistration"
  "FieldValue"
)

firebase_import_boundary_regex_for_term() {
  local term="$1"

  case "$term" in
    "import Firebase")
      printf '^import[[:space:]]+Firebase([[:space:]]|$)'
      ;;
    import\ *)
      local module="${term#import }"
      printf '^import[[:space:]]+%s([[:space:]]|$)' "$module"
      ;;
    *)
      printf '(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)' "$term"
      ;;
  esac
}

check_firebase_import_boundary() {
  if [[ ! -d "$SOURCES_DIR" ]]; then
    return 0
  fi

  local regexes=()
  local term
  for term in "${FIREBASE_IMPORT_BOUNDARY_TERMS[@]}"; do
    regexes+=("$(firebase_import_boundary_regex_for_term "$term")")
  done

  local combined_regex
  combined_regex="$(IFS='|'; printf '%s' "${regexes[*]}")"

  check_firebase_import_boundary_file_matches() {
    local swift_file="$1"

    [[ -z "$swift_file" ]] && return 0

    local relative_file
    relative_file="$(repo_relative_path "$swift_file")"

    for term in "${FIREBASE_IMPORT_BOUNDARY_TERMS[@]}"; do
      local regex
      regex="$(firebase_import_boundary_regex_for_term "$term")"

      local matches
      matches="$(grep -n -E -- "$regex" "$swift_file" || true)"

      if [[ -n "$matches" ]]; then
        add_error "$(cat <<EOF
Firebase SDK usage is only allowed inside Sources/Infrastructure. Feature code must depend on Infrastructure repositories/services, not Firebase SDK types directly. Move this Firebase usage behind an Infrastructure abstraction.
  File: $relative_file
  Matched term: $term
$(echo "$matches" | sed 's/^/  Line: /')
EOF
)"
      fi
    done
  }

  if command -v rg >/dev/null 2>&1; then
    local rg_args=(-l -g '*.swift' -g '!Infrastructure/**')
    local regex
    for regex in "${regexes[@]}"; do
      rg_args+=(-e "$regex")
    done
    while IFS= read -r swift_file; do
      [[ -z "$swift_file" ]] && continue
      check_firebase_import_boundary_file_matches "$SOURCES_DIR/${swift_file#./}"
    done < <(
      cd "$SOURCES_DIR"
      rg "${rg_args[@]}" . || true
    )
  else
    while IFS= read -r swift_file; do
      [[ -z "$swift_file" ]] && continue

      if grep -q -E -- "$combined_regex" "$swift_file"; then
        check_firebase_import_boundary_file_matches "$swift_file"
      fi
    done < <(find "$SOURCES_DIR" -type f -name '*.swift' ! -path "$SOURCES_DIR/Infrastructure/*")
  fi
}

register_linter "Firebase import boundary" check_firebase_import_boundary
