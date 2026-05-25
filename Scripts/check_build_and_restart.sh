#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
APP_NAME="AIAssistantHub"
PROJECT_FILE="$ROOT_DIR/AIAssistantHub.xcodeproj"
DERIVED_DATA="$ROOT_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/${APP_NAME}.app"

"$ROOT_DIR/Scripts/sanitize_file_endings.sh"
"$ROOT_DIR/Scripts/regenerate_app_icon.sh"
cd "$ROOT_DIR"
xcodegen generate
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
xcodebuild -project "$PROJECT_FILE" -scheme "$APP_NAME" -configuration Debug -derivedDataPath "$DERIVED_DATA"
open "$APP_PATH"
