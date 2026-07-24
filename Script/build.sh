#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .root ]; then
    echo "[*] malformed project structure"
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: ./build.sh [options]

Options:
  --source <path>          Use an existing Ghostty checkout.
  --ref <tag-or-commit>    Checkout the given ref in the source checkout.
                           Defaults to the pinned commit recorded in
                           ./GHOSTTY_REF. Pass --ref HEAD to build whatever
                           is currently checked out instead (e.g. a local
                           Ghostty fork you're iterating on).
  --platforms <csv>        Build platform groups. Default:
                           macos,ios,maccatalyst
  --download-url <url>     Generate Package.swift from Package.swift.template.
  --skip-tests             Skip local xcodebuild and swift test verification.
  -h, --help               Show this help.

Notes:
  - See ./TOOLCHAIN_VERSIONS for the Xcode/Zig versions last verified to
    build GHOSTTY_REF successfully. Update it after rebuilding.
  - Default source path is ./References/ghostty-upstream
  - This builds real per-target static archives, then assembles
    BinaryTarget/GhosttyKit.xcframework and build/GhosttyKit.xcframework.zip
  - Upstream Ghostty patches from ./Patches/ghostty are applied automatically
  - Current verified groups: macos, ios, maccatalyst
  - Current upstream Ghostty crashes for: tvos, visionos, watchos
  - Building without an immutable ref is refused: cloning the moving
    default branch at whatever moment a fresh checkout happens to run
    would make this build unreproducible. Update ./GHOSTTY_REF (a single
    commit SHA) when deliberately advancing to a newer upstream commit.
EOF
}

ROOT_DIR=$(pwd)
SOURCE_DIR="$ROOT_DIR/References/ghostty-upstream"
PLATFORMS="macos,ios,maccatalyst"
DOWNLOAD_URL=${DOWNLOAD_URL:-}
GHOSTTY_REF=
SKIP_TESTS=0

while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --ref)
            GHOSTTY_REF="$2"
            shift 2
            ;;
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --download-url)
            DOWNLOAD_URL="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "[!] unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if ! command -v zig >/dev/null 2>&1; then
    echo "[!] zig not found"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "[*] ghostty source not found, cloning into $SOURCE_DIR"
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone https://github.com/ghostty-org/ghostty "$SOURCE_DIR"
fi

if [ -z "$GHOSTTY_REF" ]; then
    PINNED_REF_FILE="$ROOT_DIR/GHOSTTY_REF"
    if [ ! -f "$PINNED_REF_FILE" ]; then
        echo "[!] no --ref given and $PINNED_REF_FILE does not exist"
        echo "[!] refusing to build against a moving default branch"
        exit 1
    fi
    GHOSTTY_REF=$(tr -d '[:space:]' < "$PINNED_REF_FILE")
    echo "[*] using pinned ghostty ref from GHOSTTY_REF: $GHOSTTY_REF"
fi

if [ "$GHOSTTY_REF" != "HEAD" ]; then
    echo "[*] checking out ghostty ref: $GHOSTTY_REF"
    if ! git -C "$SOURCE_DIR" rev-parse "$GHOSTTY_REF^{commit}" >/dev/null 2>&1; then
        git -C "$SOURCE_DIR" fetch origin "$GHOSTTY_REF"
    fi
    git -C "$SOURCE_DIR" checkout "$GHOSTTY_REF"
fi

RESOLVED_REF=$(git -C "$SOURCE_DIR" rev-parse HEAD)
if [ "$GHOSTTY_REF" != "HEAD" ]; then
    EXPECTED_REF=$(git -C "$SOURCE_DIR" rev-parse "$GHOSTTY_REF^{commit}")
    if [ "$RESOLVED_REF" != "$EXPECTED_REF" ]; then
        echo "[!] ghostty HEAD mismatch: expected $EXPECTED_REF, found $RESOLVED_REF"
        exit 1
    fi
fi
echo "[*] ghostty source resolved to: $RESOLVED_REF"

EXPECTED_GHOSTTY_REF="$RESOLVED_REF" ./Script/apply-patches.sh "$SOURCE_DIR"
export SKIP_GHOSTTY_PATCHES=1

ARTIFACTS_DIR="$ROOT_DIR/build/artifacts"
XCFRAMEWORK_PATH="$ROOT_DIR/BinaryTarget/GhosttyKit.xcframework"
XCFRAMEWORK_ZIP="$ROOT_DIR/build/GhosttyKit.xcframework.zip"
STAGING_ROOT="$ROOT_DIR/build/staging"
STAGED_ARTIFACTS_DIR="$STAGING_ROOT/artifacts"
STAGED_XCFRAMEWORK_PATH="$STAGING_ROOT/GhosttyKit.xcframework"
STAGED_XCFRAMEWORK_ZIP="$STAGING_ROOT/GhosttyKit.xcframework.zip"

rm -rf "$ARTIFACTS_DIR" "$STAGING_ROOT"
mkdir -p "$ARTIFACTS_DIR" "$STAGED_ARTIFACTS_DIR" "$(dirname "$XCFRAMEWORK_PATH")"

echo "[*] zig version: $(zig version)"
echo "[*] ghostty source: $SOURCE_DIR"
echo "[*] platform groups: $PLATFORMS"

OLD_IFS=$IFS
IFS=','
set -- $PLATFORMS
IFS=$OLD_IFS

for platform_group in "$@"; do
    platform_group=$(echo "$platform_group" | xargs)
    [ -n "$platform_group" ] || continue
    ./Script/build-platform.sh "$SOURCE_DIR" "$platform_group" "$STAGED_ARTIFACTS_DIR"
done

./Script/merge-xcframework.sh \
    "$STAGED_ARTIFACTS_DIR" \
    "$STAGED_XCFRAMEWORK_PATH" \
    "$STAGED_XCFRAMEWORK_ZIP"

# Do not remove the last usable binary until every requested slice has built
# and a complete replacement XCFramework + zip exists in staging.
rm -rf "$XCFRAMEWORK_PATH"
rm -f "$XCFRAMEWORK_ZIP"
mv "$STAGED_XCFRAMEWORK_PATH" "$XCFRAMEWORK_PATH"
mv "$STAGED_XCFRAMEWORK_ZIP" "$XCFRAMEWORK_ZIP"
rm -rf "$STAGING_ROOT"

BUILD_INFO="$ROOT_DIR/build/BUILD_INFO.txt"
ARTIFACT_SHA256=$(shasum -a 256 "$XCFRAMEWORK_ZIP" | cut -d ' ' -f 1)
SWIFTPM_CHECKSUM=$(swift package compute-checksum "$XCFRAMEWORK_ZIP")
{
    echo "ghostty_repository=https://github.com/ghostty-org/ghostty"
    echo "ghostty_ref=$GHOSTTY_REF"
    echo "ghostty_resolved_commit=$RESOLVED_REF"
    echo "xcode=$(xcodebuild -version | paste -sd ' ' -)"
    echo "zig=$(zig version)"
    echo "swift=$(swift --version | head -n 1)"
    echo "sdk_versions:"
    echo "  macosx=$(xcrun --sdk macosx --show-sdk-version)"
    echo "  iphoneos=$(xcrun --sdk iphoneos --show-sdk-version)"
    echo "  iphonesimulator=$(xcrun --sdk iphonesimulator --show-sdk-version)"
    echo "artifact=build/GhosttyKit.xcframework.zip"
    echo "artifact_sha256=$ARTIFACT_SHA256"
    echo "artifact_swiftpm_checksum=$SWIFTPM_CHECKSUM"
    echo "patches:"
    for patch_file in "$ROOT_DIR"/Patches/ghostty/*; do
        [ -f "$patch_file" ] || continue
        [ "${patch_file##*.}" = "md" ] && continue
        echo "  $(basename "$patch_file") $(shasum -a 256 "$patch_file" | cut -d ' ' -f 1)"
    done
    echo "licensing=Ghostty source and linked dependencies retain their upstream licenses; review redistribution obligations before publishing the binary."
} > "$BUILD_INFO"

if [ -n "$DOWNLOAD_URL" ]; then
    ./Script/build-manifest.sh "$XCFRAMEWORK_ZIP" "$DOWNLOAD_URL"
fi

if [ "$SKIP_TESTS" -eq 0 ]; then
    ./Script/test.sh
    swift test
fi

echo "[*] xcframework: $XCFRAMEWORK_PATH"
echo "[*] zip: $XCFRAMEWORK_ZIP"
echo "[*] build info: $BUILD_INFO"
echo "[*] sha256: $ARTIFACT_SHA256"
echo "[*] swiftpm checksum: $SWIFTPM_CHECKSUM"
