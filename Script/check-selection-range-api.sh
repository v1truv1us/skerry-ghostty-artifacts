#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

XCFRAMEWORK_PATH=${1:-BinaryTarget/GhosttyKit.xcframework}
EXPECTED_SYMBOL=_ghostty_surface_selection_range
SYMBOLS_FILE=$(mktemp "${TMPDIR:-/tmp}/ghostty-selection-symbols.XXXXXX")
trap 'rm -f "$SYMBOLS_FILE"' EXIT INT TERM

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo "[!] XCFramework not found: $XCFRAMEWORK_PATH"
    exit 1
fi

header_count=0
while IFS= read -r -d '' header; do
    header_count=$((header_count + 1))
    if ! rg -q 'ghostty_surface_selection_range\(ghostty_surface_t,' "$header" \
        || ! rg -q 'ghostty_selection_range_s\*\);' "$header" \
        || ! rg -q 'double leading_x;' "$header" \
        || ! rg -q 'bool trailing_visible;' "$header"; then
        echo "[!] selection-range declaration missing: $header"
        exit 1
    fi
done < <(find "$XCFRAMEWORK_PATH" -type f -name ghostty.h -print0)

if [ "$header_count" -eq 0 ]; then
    echo "[!] no Ghostty headers found in $XCFRAMEWORK_PATH"
    exit 1
fi

library_count=0
while IFS= read -r -d '' library; do
    library_count=$((library_count + 1))
    nm -gU "$library" > "$SYMBOLS_FILE"
    if ! rg -q "$EXPECTED_SYMBOL" "$SYMBOLS_FILE"; then
        echo "[!] selection-range symbol missing: $library"
        exit 1
    fi
done < <(find "$XCFRAMEWORK_PATH" -type f -name libghostty.a -print0)

if [ "$library_count" -eq 0 ]; then
    echo "[!] no Ghostty archives found in $XCFRAMEWORK_PATH"
    exit 1
fi

echo "[*] authoritative selection-range API present in $header_count headers and $library_count archives"
