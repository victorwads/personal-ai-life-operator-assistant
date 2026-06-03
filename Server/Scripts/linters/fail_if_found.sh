#!/usr/bin/env bash

RULE_PATTERNS=()
RULE_SCOPES=()
RULE_MESSAGES=()

TEMP_FILES=()
LAST_TEMP_FILE=""

cleanup_fail_if_found_temp_files() {
  for file in "${TEMP_FILES[@]}"; do
    rm -f "$file"
  done
}

trap cleanup_fail_if_found_temp_files EXIT

create_temp_file() {
  LAST_TEMP_FILE="$(mktemp)"
  TEMP_FILES+=("$LAST_TEMP_FILE")
}

fail_if_found() {
  local pattern="$1"
  local message="$2"
  local scope="${3:-Sources}"

  RULE_PATTERNS+=("$pattern")
  RULE_SCOPES+=("$scope")
  RULE_MESSAGES+=("$message")
}

register_default_fail_if_found_rules() {
  fail_if_found "mergingForUpsert" "Do not put merge/upsert behavior in models or model protocols."

  fail_if_found "sourceMessageId" "Message ids must already include source prefix." "Sources/Features/Chats"
  fail_if_found "sourceChatId" "Chat ids must already include source prefix." "Sources/Features/Chats"

  fail_if_found "rawDateTimeAndAuthor" "Raw integration fields must not be stored in domain models." "Sources/Features/Chats/Models"
  fail_if_found "rawTimeText" "Raw integration fields must not be stored in domain models." "Sources/Features/Chats/Models"

  fail_if_found "Legacy" "Delete unused files instead of marking them Legacy."
  fail_if_found "Unused" "Delete unused files instead of marking them Unused."
  fail_if_found "Deprecated" "Delete unused files instead of marking them Deprecated."
  fail_if_found "Do not use" "Delete unused files instead of marking them Do not use."
  fail_if_found "DO NOT USE" "Delete unused files instead of marking them DO NOT USE."
  fail_if_found "do not use" "Delete unused files instead of marking them do not use."
}

run_fail_if_found_linter() {
  register_default_fail_if_found_rules
  verify_fail_if_found_rules
}

verify_fail_if_found_rules() {
  if [[ ${#RULE_PATTERNS[@]} -eq 0 ]]; then
    return 0
  fi

  if [[ ! -d "$SOURCES_DIR" ]]; then
    return 0
  fi

  local patterns_file
  create_temp_file
  patterns_file="$LAST_TEMP_FILE"

  local pattern
  for pattern in "${RULE_PATTERNS[@]}"; do
    printf '%s\n' "$pattern" >> "$patterns_file"
  done

  local matched_files_file
  create_temp_file
  matched_files_file="$LAST_TEMP_FILE"

  grep -R -l -F -f "$patterns_file" "$SOURCES_DIR" > "$matched_files_file" || true

  local file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    local relative_file
    relative_file="$(repo_relative_path "$file")"

    local index
    for (( index = 0; index < ${#RULE_PATTERNS[@]}; index++ )); do
      local rule_pattern="${RULE_PATTERNS[$index]}"
      local rule_scope="${RULE_SCOPES[$index]}"
      local rule_message="${RULE_MESSAGES[$index]}"

      local absolute_scope
      if [[ "$rule_scope" = /* ]]; then
        absolute_scope="$rule_scope"
      else
        absolute_scope="$ROOT_DIR/$rule_scope"
      fi

      if [[ "$file" != "$absolute_scope"* ]]; then
        continue
      fi

      local matches
      matches="$(grep -n -F -- "$rule_pattern" "$file" || true)"

      if [[ -n "$matches" ]]; then
        add_error "$(cat <<EOF
$rule_message
  File: $relative_file
  Pattern: $rule_pattern
$(echo "$matches" | sed 's/^/  Line: /')
  Fix the reported source file. Do not edit scripts/lint.sh or linter modules to bypass this rule.
EOF
)"
      fi
    done
  done < "$matched_files_file"
}

register_linter "Forbidden text patterns" run_fail_if_found_linter
