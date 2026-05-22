#!/usr/bin/env bash
set -euo pipefail

# Resets macOS TCC permissions for this app so you can re-test prompts.
# Usage:
#   ./scripts/tccutil-reset-permissions.sh
#   BUNDLE_ID=dev.wads.AssistantMCPServer ./scripts/tccutil-reset-permissions.sh

echo "Closing running AssistantMCPServer instances..."
osascript -e 'tell application "AssistantMCPServer" to quit' >/dev/null 2>&1 || true
pkill -x AssistantMCPServer 2>/dev/null || true
pkill -f 'debugserver.*AssistantMCPServer' 2>/dev/null || true

BUNDLE_ID="${BUNDLE_ID:-dev.wads.AssistantMCPServer}"

echo "Resetting TCC permissions for: ${BUNDLE_ID}"

tccutil reset All "${BUNDLE_ID}"

echo "Done. Relaunch the app and click the Voice badge to re-request permissions."

