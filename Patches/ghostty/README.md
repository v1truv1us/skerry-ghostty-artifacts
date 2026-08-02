# Ghostty Patches

This directory is the single place for local upstream Ghostty patches used by
the `libghostty-spm` build pipeline.

## Rules

- Keep patches numbered so they apply in a stable order.
- Prefer standard unified diff files (`.patch`) when the upstream context is
  stable.
- Use executable patch scripts (`.sh`) only when upstream context is too
  unstable for a reliable diff.
- Every patch script should detect its own marker, but the orchestrator only
  accepts a clean checkout at the pinned commit. This prevents partially
  applied patch sets from being mistaken for a reproducible source state.
- Keep version-specific variants beside the original patch and select them in
  `Script/apply-patches.sh` using an upstream API marker.
- Preserve newer Ghostty's renamed internal-library outputs when extending its
  Darwin static-library build path.
- Every patch in this directory must be safe to re-run.
- Patches here are applied automatically by `Script/build-ghostty.sh`, so they
  affect macOS, iOS, and Mac Catalyst builds equally.
- `0012-zig16-maccatalyst.patch` maps Ghostty's Apple platform branches to
  Zig 0.16's `maccatalyst` tag. `0013-libxev-maccatalyst.sh` runs only after
  Zig fetches the checksum-pinned libxev dependency, validates the exact old
  allowlist shape, and adds the same tag without modifying unrelated cache
  content.
- `0011-selection-range.patch` exposes only endpoint geometry and visibility;
  it must never expose, decode, or log selected terminal text.
- `0014-disable-libintl-without-i18n.patch` keeps upstream desktop behavior but
  omits GNU libintl when this host-managed build explicitly disables Ghostty
  translations. `Script/check-no-libintl.sh` audits every published slice so
  a future build-graph change cannot silently restore the static dependency.

## Current goal

This patch workflow exists so we can carry host-managed IO work required for
sandboxed iOS, macOS, and Mac Catalyst integration, plus the content-free
selection-range bridge required for native iOS handles, without hiding upstream
modifications inside ad-hoc build script edits.
