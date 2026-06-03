#!/usr/bin/env bash
set -euo pipefail

# Linter orchestrator.
#
# If this script fails, fix the source files that violate the rule.
# Do not remove rules.
# Do not weaken rules.
# Do not rename forbidden words just to bypass the check.
# Do not edit linter scripts unless the user explicitly asks to change lint rules.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES_DIR="$ROOT_DIR/Sources"
DOCS_ARCHITECTURE="$ROOT_DIR/../Docs/Architecture.md"
THIS_SCRIPT="$SCRIPT_DIR/lint.sh"
LINTER_WARNING_THRESHOLD_SECONDS=1

ERRORS=()
WARNINGS=()
REGISTERED_LINTER_NAMES=()
REGISTERED_LINTER_FUNCTIONS=()

add_error() {
  ERRORS+=("$1")
}

add_warning() {
  WARNINGS+=("$1")
}

format_elapsed_seconds() {
  local elapsed_seconds="$1"
  printf '%ss' "$elapsed_seconds"
}

run_timed_step() {
  local start_label="$1"
  local step_name="$2"
  local step_command="$3"
  local started_at="$SECONDS"

  shift 3

  printf '%s: %s ... ' "$start_label" "$step_name"
  "$step_command" "$@"
  local elapsed_seconds="$((SECONDS - started_at))"
  echo "$(format_elapsed_seconds "$elapsed_seconds")"
  RUN_TIMED_STEP_ELAPSED_SECONDS="$elapsed_seconds"
}

register_linter() {
  local linter_name="$1"
  local linter_function="$2"

  REGISTERED_LINTER_NAMES+=("$linter_name")
  REGISTERED_LINTER_FUNCTIONS+=("$linter_function")
}

repo_relative_path() {
  local path="$1"
  echo "${path#"$ROOT_DIR/"}"
}

load_linter_scripts() {
  local linter_script

  shopt -s nullglob
  for linter_script in "$SCRIPT_DIR"/linters/*.sh; do
    run_timed_step "Loading linter script" "$(basename "$linter_script")" source_linter_script "$linter_script"
  done
  shopt -u nullglob
}

source_linter_script() {
  local linter_script="$1"

  . "$linter_script"
}

run_registered_linters() {
  local index
  for (( index = 0; index < ${#REGISTERED_LINTER_FUNCTIONS[@]}; index++ )); do
    run_timed_step "Running linter" "${REGISTERED_LINTER_NAMES[$index]}" "${REGISTERED_LINTER_FUNCTIONS[$index]}"

    if (( RUN_TIMED_STEP_ELAPSED_SECONDS > LINTER_WARNING_THRESHOLD_SECONDS )); then
      add_warning "Linter is slower than expected.
  Linter: ${REGISTERED_LINTER_NAMES[$index]}
  Duration: $(format_elapsed_seconds "$RUN_TIMED_STEP_ELAPSED_SECONDS")
  Target: at most ${LINTER_WARNING_THRESHOLD_SECONDS}s
  Refactor this linter to keep the same behavior with less work."
    fi
  done
}

load_linter_scripts

for linter_function in "${REGISTERED_LINTER_FUNCTIONS[@]}"; do
  if ! declare -F "$linter_function" >/dev/null 2>&1; then
    add_error "Registered linter function was not found.
  Function: $linter_function
  Fix the linter registration in Scripts/linters."
  fi
done

if (( ${#REGISTERED_LINTER_NAMES[@]} != ${#REGISTERED_LINTER_FUNCTIONS[@]} )); then
  add_error "Registered linter metadata is inconsistent.
  Names: ${#REGISTERED_LINTER_NAMES[@]}
  Functions: ${#REGISTERED_LINTER_FUNCTIONS[@]}
  Fix the registrations in Scripts/linters."
fi

check_linter_scripts_were_not_modified() {
  if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  local status
  status="$(
    {
      git -C "$ROOT_DIR" diff --name-only --diff-filter=MDR -- Scripts/lint.sh Scripts/linters
      git -C "$ROOT_DIR" diff --cached --name-only --diff-filter=MDR -- Scripts/lint.sh Scripts/linters
    } | awk 'NF && !seen[$0]++'
  )"

  if [[ -z "$status" ]]; then
    return 0
  fi

  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    add_error "This linter file is protected.
Restore this file before continuing.
Do not edit linter scripts.
Do not bypass lint rules.
Fix the reported source files instead.
  Changed file: $line"
  done <<< "$status"
}

register_linter "Protected linter scripts" check_linter_scripts_were_not_modified
run_registered_linters

if (( ${#WARNINGS[@]} > 0 )); then
  echo "Lint warnings:"
  echo

  for warning in "${WARNINGS[@]}"; do
    echo "$warning"
    echo
  done
fi

if (( ${#ERRORS[@]} > 0 )); then
  echo "Lint violations:"
  echo

  for error in "${ERRORS[@]}"; do
    echo "$error"
    echo
  done

  echo "How to fix:"
  echo "- Fix the reported source files."
  echo "- Do not remove, weaken, rename, or bypass linter rules."
  echo "- If a file is unused, delete it instead of marking it Legacy/Unused/Deprecated/Do not use."

  exit 1
fi

echo "Lint passed."
