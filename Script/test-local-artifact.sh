#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -d BinaryTarget/GhosttyKit.xcframework ]; then
    echo "[!] local Ghostty XCFramework is missing"
    exit 1
fi

./Script/check-selection-range-api.sh BinaryTarget/GhosttyKit.xcframework

MANIFEST_BACKUP=$(mktemp "${TMPDIR:-/tmp}/libghostty-spm-Package.swift.XXXXXX")

restore_manifest() {
    [ -f "$MANIFEST_BACKUP" ] || return 0
    cp "$MANIFEST_BACKUP" Package.swift
    rm -f "$MANIFEST_BACKUP"
}
trap restore_manifest EXIT INT TERM

# Release verification must exercise the artifact that was just built. The
# production manifest deliberately resolves an immutable remote URL, so leaving
# it active here would silently retest the previous published binary instead.
cp Package.swift "$MANIFEST_BACKUP"
cp Package.local.swift Package.swift

./Script/test.sh
swift test

restore_manifest
trap - EXIT INT TERM

echo "[*] local Ghostty artifact tests passed"
