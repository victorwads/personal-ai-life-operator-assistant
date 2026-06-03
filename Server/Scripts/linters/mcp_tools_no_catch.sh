#!/usr/bin/env bash
set -euo pipefail

check_mcp_tools_do_not_catch() {
  if ! command -v rg >/dev/null 2>&1; then
    return 0
  fi

  local matches
  matches="$(rg -n --glob "Sources/Features/**/MCP/*.swift" "\\bcatch\\b" "$ROOT_DIR" || true)"

  if [[ -z "$matches" ]]; then
    return 0
  fi

  add_error "$(cat <<EOF
Do not use local catch blocks inside MCP tool definition files.
MCP tools should throw and let MCPToolExecutor map errors to MCPToolExecutionResult.
  Fix: remove the catch block and throw errors instead.
  Matches:
$(echo "$matches" | sed 's/^/  /')
EOF
)"
}

register_linter "MCP tools without catch" check_mcp_tools_do_not_catch
