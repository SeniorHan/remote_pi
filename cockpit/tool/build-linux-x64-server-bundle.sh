#!/usr/bin/env bash
# Fork-only: linux-x64 twin of build-linux-arm64-server-bundle.sh.
# Cross-compiles the cockpit-server bundle for x86_64 Linux remote hosts
# (the upstream script targets aarch64 only).
# Usage: tool/build-linux-x64-server-bundle.sh <destination>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:?destination is required}"
TARGET="x86_64-unknown-linux-gnu"

resolve_tool() {
  local name="$1" fallback="${2:-}"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
  elif [ -n "$fallback" ] && [ -x "$fallback" ]; then
    echo "$fallback"
  else
    echo "[linux-server-x64] error: '$name' not found" >&2
    exit 1
  fi
}

if [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/dart" ]; then
  DART="$FLUTTER_ROOT/bin/dart"
else
  DART="$(resolve_tool dart)"
fi
ZIG="$(resolve_tool zig)"
CARGO="$(resolve_tool cargo "$HOME/.cargo/bin/cargo")"
RUSTUP="$(resolve_tool rustup "$HOME/.cargo/bin/rustup")"

if ! "$RUSTUP" target list --installed | grep -qx "$TARGET"; then
  echo "[linux-server-x64] error: Rust target '$TARGET' is not installed" >&2
  echo "[linux-server-x64] run: rustup target add $TARGET" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rm -rf "$DEST"
mkdir -p "$DEST"

(
  cd "$ROOT/packages/cockpit_server"
  "$DART" pub get >/dev/null
  "$DART" build cli \
    --target-os linux \
    --target-arch x64 \
    -o "$TMP/dart" >/dev/null
)
mv "$TMP/dart/bundle"/* "$DEST"/
mv "$DEST/bin/cockpit_server" "$DEST/bin/cockpit-server"
if [ -f "$DEST/lib/libdartaotcockpit_server.so" ]; then
  mv "$DEST/lib/libdartaotcockpit_server.so" "$DEST/lib/libdartaotcockpit-server.so"
fi

"$ZIG" cc -target x86_64-linux-gnu -shared -O2 -DDART_SHARED_LIB \
  -o "$DEST/lib/libcockpit_pty.so" \
  "$ROOT/plugins/cockpit_pty/src/cockpit_pty.c" \
  -I"$ROOT/plugins/cockpit_pty/src" -lpthread

ZIG_LINKER="$TMP/zig-x86_64-linux-gnu-cc"
cat >"$ZIG_LINKER" <<EOF
#!/bin/sh
for arg do
  shift
  [ "\$arg" = "-Wl,--fix-cortex-a53-843419" ] && continue
  set -- "\$@" "\$arg"
done
exec "$ZIG" cc -target x86_64-linux-gnu "\$@"
EOF
chmod +x "$ZIG_LINKER"
(
  cd "$ROOT/cli"
  CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$ZIG_LINKER" \
    "$CARGO" build --release --target "$TARGET" >/dev/null
)
cp "$ROOT/cli/target/$TARGET/release/cockpit" "$DEST/bin/cockpit"
chmod +x "$DEST/bin/cockpit-server" "$DEST/bin/cockpit"

echo "[linux-server-x64] bundle OK -> $DEST"
