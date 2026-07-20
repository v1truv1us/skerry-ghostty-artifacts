#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .root ]; then
    echo "[-] malformed project structure"
    exit 1
fi

SDK_PATH=${1:-}
OUT_FILE=${2:-}

if [ -z "$SDK_PATH" ] || [ -z "$OUT_FILE" ]; then
    echo "Usage: $0 <sdk_path> <out_file>"
    exit 1
fi

if [ ! -d "$SDK_PATH/usr/include" ] || [ ! -d "$SDK_PATH/usr/lib" ]; then
    echo "[-] not a usable SDK (missing usr/include or usr/lib): $SDK_PATH"
    exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"
cat >"$OUT_FILE" <<EOF
include_dir=$SDK_PATH/usr/include
sys_include_dir=$SDK_PATH/usr/include
crt_dir=$SDK_PATH/usr/lib
msvc_lib_dir=
kernel32_lib_dir=
gcc_dir=
EOF

SDK_VERSION=$(/usr/bin/plutil -extract Version raw "$SDK_PATH/SDKSettings.json" 2>/dev/null || echo "unknown")
echo "[+] libc manifest: $OUT_FILE -> $SDK_PATH (sdk $SDK_VERSION)"
