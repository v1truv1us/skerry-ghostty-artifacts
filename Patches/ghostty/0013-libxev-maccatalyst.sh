#!/bin/bash

set -euo pipefail

SOURCE_DIR="${1:?Usage: $0 <ghostty-source-dir>}"

# Zig 0.16 models Mac Catalyst as its own OS tag. Current upstream libxev
# predates that tag and otherwise rejects Catalyst before Ghostty can compile.
# The dependency is immutable and checksum-verified by Zig; patch only its
# explicit Darwin allowlists after Zig materializes it in the clean checkout.
XEV_DIR=
XEV_COUNT=0
while IFS= read -r candidate; do
    XEV_DIR=$candidate
    XEV_COUNT=$((XEV_COUNT + 1))
done < <(find "$SOURCE_DIR/zig-pkg" -maxdepth 1 -type d -name 'libxev-*' -print 2>/dev/null || true)
if [ "$XEV_COUNT" -eq 0 ]; then
    echo "[+] libxev not materialized yet; Catalyst compatibility deferred until dependency fetch"
    exit 0
fi
if [ "$XEV_COUNT" -ne 1 ]; then
    echo "[!] expected one materialized libxev dependency, found $XEV_COUNT"
    exit 1
fi

python3 - "$XEV_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
replacements = {
    root / "src/backend.zig": [
        (".ios, .macos, .visionos => .kqueue,", ".ios, .macos, .maccatalyst, .visionos => .kqueue,"),
        (".ios, .macos, .visionos => &.{.kqueue},", ".ios, .macos, .maccatalyst, .visionos => &.{.kqueue},"),
    ],
    root / "src/posix.zig": [
        (
            ".macos, .ios, .watchos, .tvos, .visionos => maxInt(i32),",
            ".macos, .ios, .maccatalyst, .watchos, .tvos, .visionos => maxInt(i32),",
        ),
    ],
    root / "src/backend/kqueue.zig": [
        (".ios, .macos, .visionos => true,", ".ios, .macos, .maccatalyst, .visionos => true,"),
        (
            ".ios, .macos, .visionos => std.c.NOTE.EXIT | std.c.NOTE.EXITSTATUS,",
            ".ios, .macos, .maccatalyst, .visionos => std.c.NOTE.EXIT | std.c.NOTE.EXITSTATUS,",
        ),
        (
            ".ios, .macos, .visionos => posix.system.kevent64_s,",
            ".ios, .macos, .maccatalyst, .visionos => posix.system.kevent64_s,",
        ),
    ],
}

for path, pairs in replacements.items():
    source = path.read_text()
    for old, new in pairs:
        if new in source:
            continue
        count = source.count(old)
        if count == 0:
            raise SystemExit(f"[!] libxev Catalyst context missing: {path}: {old}")
        source = source.replace(old, new)
    path.write_text(source)

backend = (root / "src/backend.zig").read_text()
posix = (root / "src/posix.zig").read_text()
kqueue = (root / "src/backend/kqueue.zig").read_text()
if backend.count(".maccatalyst") != 2:
    raise SystemExit("[!] libxev backend Catalyst validation failed")
if posix.count(".maccatalyst") != 4:
    raise SystemExit("[!] libxev POSIX Catalyst validation failed")
if kqueue.count(".maccatalyst") != 3:
    raise SystemExit("[!] libxev kqueue Catalyst validation failed")

print("[+] patched materialized libxev for Zig 0.16 Mac Catalyst")
PY
