#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

XCFRAMEWORK_PATH=${1:-BinaryTarget/GhosttyKit.xcframework}
SYMBOLS_FILE=$(mktemp "${TMPDIR:-/tmp}/ghostty-libintl-symbols.XXXXXX")
trap 'rm -f "$SYMBOLS_FILE"' EXIT INT TERM

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo "[!] XCFramework not found: $XCFRAMEWORK_PATH"
    exit 1
fi

library_count=0
while IFS= read -r -d '' library; do
    library_count=$((library_count + 1))
    nm -gU "$library" > "$SYMBOLS_FILE"
    if rg -q '(_libintl_|__libintl_| _gettext$| _dgettext$| _dcgettext$| _ngettext$| _dngettext$| _dcngettext$| _textdomain$| _bindtextdomain$)' "$SYMBOLS_FILE"; then
        echo "[!] bundled libintl symbols found: $library"
        exit 1
    fi
done < <(find "$XCFRAMEWORK_PATH" -type f -name libghostty.a -print0)

if [ "$library_count" -eq 0 ]; then
    echo "[!] no Ghostty archives found in $XCFRAMEWORK_PATH"
    exit 1
fi

echo "[*] no bundled libintl symbols in $library_count archives"
