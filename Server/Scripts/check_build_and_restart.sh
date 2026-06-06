#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
APP_NAME="AIAssistantHub"
PROJECT_FILE="$ROOT_DIR/AIAssistantHub.xcodeproj"
SCHEME_NAME="${SCHEME_NAME:-AIAssistantHub}"
CONFIGURATION="Debug"
TEST_DESTINATION="platform=macOS"
APP_ICON_DIR="$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
XCODEBUILD_ARGS=(
  -project "$PROJECT_FILE"
  -scheme "$SCHEME_NAME"
  -configuration "$CONFIGURATION"
)

echo "==> Sanitizing file endings"
"$ROOT_DIR/Scripts/sanitize_file_endings.sh"

echo "==> Checking app icon"
icon_pngs=("$APP_ICON_DIR"/*.png(N))
if (( ${#icon_pngs} == 0 )); then
  "$ROOT_DIR/Scripts/regenerate_app_icon.sh"
fi

echo "==> Running linters"
bash "$ROOT_DIR/Scripts/lint.sh"

cd "$ROOT_DIR"
echo "==> Generating Xcode project"
xcodegen generate

build_settings="$(xcodebuild "${XCODEBUILD_ARGS[@]}" -showBuildSettings)"
target_build_dir="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/TARGET_BUILD_DIR = / {print $2; exit}')"
full_product_name="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/FULL_PRODUCT_NAME = / {print $2; exit}')"

if [[ -z "$target_build_dir" || -z "$full_product_name" ]]; then
  echo "Failed to read TARGET_BUILD_DIR or FULL_PRODUCT_NAME from xcodebuild settings." >&2
  exit 1
fi

APP_PATH="$target_build_dir/$full_product_name"

echo "==> Building"
xcodebuild "${XCODEBUILD_ARGS[@]}" build

echo "==> Running unit tests"
xcodebuild "${XCODEBUILD_ARGS[@]}" -destination "$TEST_DESTINATION" test

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at: $APP_PATH" >&2
  exit 1
fi

#echo "==> Stopping running app"
#osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
#
#echo "==> Opening built app"
#open "$APP_PATH"
