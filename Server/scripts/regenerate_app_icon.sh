#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_SVG="${REPO_ROOT}/Sources/Assets.xcassets/BrandIcon.imageset/assistant-app-icon.svg"
DEFAULT_OUT_DIR="${REPO_ROOT}/Sources/Assets.xcassets/AppIcon.appiconset"

INPUT_SVG="${1:-$DEFAULT_SVG}"
OUT_DIR="${2:-$DEFAULT_OUT_DIR}"

if [[ ! -f "${INPUT_SVG}" ]]; then
  echo "error: SVG not found: ${INPUT_SVG}" >&2
  exit 1
fi

if [[ ! -d "${OUT_DIR}" ]]; then
  echo "error: output dir not found: ${OUT_DIR}" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script currently supports macOS only (uses qlmanage + sips)" >&2
  exit 1
fi

QLMANAGE="${QLMANAGE:-/usr/bin/qlmanage}"
SIPS="${SIPS:-/usr/bin/sips}"

if [[ ! -x "${QLMANAGE}" ]]; then
  echo "error: qlmanage not found/executable at: ${QLMANAGE}" >&2
  exit 1
fi
if [[ ! -x "${SIPS}" ]]; then
  echo "error: sips not found/executable at: ${SIPS}" >&2
  exit 1
fi

TMP_DIR="${REPO_ROOT}/build/appicon-tmp"
mkdir -p "${TMP_DIR}"

SVG_BASENAME="$(basename "${INPUT_SVG}")"
TMP_PNG="${TMP_DIR}/${SVG_BASENAME}.png"
rm -f "${TMP_PNG}"

echo "Rendering SVG -> PNG (1024px)"
"${QLMANAGE}" -t -s 1024 -o "${TMP_DIR}" "${INPUT_SVG}" >/dev/null

if [[ ! -f "${TMP_PNG}" ]]; then
  echo "error: expected thumbnail not found: ${TMP_PNG}" >&2
  echo "note: qlmanage output dir: ${TMP_DIR}" >&2
  exit 1
fi

declare -a SIZES=(16 32 64 128 256 512)
for SIZE in "${SIZES[@]}"; do
  OUT_PNG="${OUT_DIR}/AppIcon-${SIZE}.png"
  echo "Writing ${OUT_PNG}"
  "${SIPS}" -z "${SIZE}" "${SIZE}" "${TMP_PNG}" --out "${OUT_PNG}" >/dev/null
done

OUT_1024="${OUT_DIR}/AppIcon-1024.png"
echo "Writing ${OUT_1024}"
cp -f "${TMP_PNG}" "${OUT_1024}"

echo "Done."
echo "Input:  ${INPUT_SVG}"
echo "Output: ${OUT_DIR}"
