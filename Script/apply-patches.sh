#!/bin/zsh

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .root ]; then
    echo "[-] malformed project structure"
    exit 1
fi

SOURCE_DIR=${1:-}
PATCH_DIR=${2:-"$(pwd)/Patches/ghostty"}
EXPECTED_GHOSTTY_REF=${EXPECTED_GHOSTTY_REF:-"$(tr -d '[:space:]' < GHOSTTY_REF)"}

if [ -z "$SOURCE_DIR" ]; then
    echo "Usage: $0 <source_dir> [patch_dir]"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "[-] ghostty source directory not found: $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$PATCH_DIR" ]; then
    echo "[+] no patches directory found: $PATCH_DIR"
    exit 0
fi

if ! git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[-] ghostty source is not a git checkout: $SOURCE_DIR"
    exit 1
fi

RESOLVED_HEAD=$(git -C "$SOURCE_DIR" rev-parse HEAD)
EXPECTED_HEAD=$(git -C "$SOURCE_DIR" rev-parse "$EXPECTED_GHOSTTY_REF^{commit}")
if [ "$RESOLVED_HEAD" != "$EXPECTED_HEAD" ]; then
    echo "[-] ghostty HEAD mismatch: expected $EXPECTED_HEAD, found $RESOLVED_HEAD"
    exit 1
fi

if [ -n "$(git -C "$SOURCE_DIR" status --porcelain --untracked-files=all)" ]; then
    echo "[-] ghostty source must be clean before patches are applied: $SOURCE_DIR"
    git -C "$SOURCE_DIR" status --short
    exit 1
fi

echo "[+] verified clean ghostty source: $RESOLVED_HEAD"

apply_unified_patch() {
    local patch_file="$1"

    if [ -d "$SOURCE_DIR/.git" ] && command -v git >/dev/null 2>&1; then
        # Forward and reverse checks can both succeed when a multi-file patch
        # adds a file while another hunk resembles already-present code. The
        # orchestrator starts from a verified clean checkout, so forward must
        # win or a required patch can be silently skipped.
        if git -C "$SOURCE_DIR" apply --check "$patch_file" >/dev/null 2>&1; then
            git -C "$SOURCE_DIR" apply "$patch_file"
            echo "[+] applied patch: $(basename "$patch_file")"
            return
        fi

        if git -C "$SOURCE_DIR" apply --check --reverse "$patch_file" >/dev/null 2>&1; then
            echo "[+] patch already applied: $(basename "$patch_file")"
            return
        fi

        echo "[-] failed to validate patch: $patch_file"
        exit 1
    fi

    if patch -p1 --dry-run -d "$SOURCE_DIR" <"$patch_file" >/dev/null 2>&1; then
        patch -p1 -d "$SOURCE_DIR" <"$patch_file" >/dev/null
        echo "[+] applied patch: $(basename "$patch_file")"
        return
    fi

    if patch -p1 -R --dry-run -d "$SOURCE_DIR" <"$patch_file" >/dev/null 2>&1; then
        echo "[+] patch already applied: $(basename "$patch_file")"
        return
    fi

    echo "[-] failed to validate patch: $patch_file"
    exit 1
}

# Ghostty's host-managed I/O surface gained a foreground-PID getter partway
# through upstream's history. Older pinned refs need the original patch;
# newer ones (including ours) already declare that symbol and need the
# rebased "-modern" variant instead. Detecting this from the header keeps a
# ref bump from silently applying the wrong hunk set.
modern_host_io=false
if grep -q "ghostty_surface_foreground_pid" "$SOURCE_DIR/include/ghostty.h"; then
    modern_host_io=true
fi

host_io_applied=false
if grep -q "GHOSTTY_SURFACE_IO_BACKEND_HOST_MANAGED" "$SOURCE_DIR/include/ghostty.h"; then
    host_io_applied=true
fi

for patch_file in "$PATCH_DIR"/*; do
    [ -e "$patch_file" ] || continue

    patch_name=$(basename "$patch_file")
    case "$patch_name" in
        0002-host-managed-io.patch)
            [ "$modern_host_io" = false ] || continue
            if [ "$host_io_applied" = true ]; then
                echo "[+] patch already applied: $patch_name"
                continue
            fi
            apply_unified_patch "$patch_file"
            ;;
        0002-host-managed-io-modern.patch)
            [ "$modern_host_io" = true ] || continue
            if [ "$host_io_applied" = true ]; then
                echo "[+] patch already applied: $patch_name"
                continue
            fi
            apply_unified_patch "$patch_file"
            ;;
        *.md) ;;
        *.patch)
            apply_unified_patch "$patch_file"
            ;;
        *.sh)
            "$patch_file" "$SOURCE_DIR"
            ;;
        *)
            echo "[-] unsupported patch file: $patch_file"
            exit 1
            ;;
    esac
done
