#!/usr/bin/env bash
# Provision the fixed deductive toolchain; never update Lake pins.
set -euo pipefail
FMK_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
export PATH="${ELAN_HOME:-$HOME/.elan}/bin:$PATH"
if ! command -v elan >/dev/null; then
  FMK_TMP=$(mktemp -d)
  trap 'rm -rf "$FMK_TMP"' EXIT
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64) FMK_TARGET=x86_64-unknown-linux-gnu; FMK_SHA=42b94d4244e8353142c456ec0e4ca6528fd898a6c604d4059f494e706e431f63 ;;
    *) echo 'Install elan 4.2.4 for this platform before provisioning.' >&2; exit 2 ;;
  esac
  curl --retry 5 --retry-all-errors -fsSL "https://github.com/leanprover/elan/releases/download/v4.2.4/elan-$FMK_TARGET.tar.gz" -o "$FMK_TMP/elan.tar.gz"
  printf '%s  %s\n' "$FMK_SHA" "$FMK_TMP/elan.tar.gz" | sha256sum --check --strict -
  tar --no-same-owner -xzf "$FMK_TMP/elan.tar.gz" -C "$FMK_TMP"
  "$FMK_TMP/elan-init" -y --no-modify-path --default-toolchain none
fi
cd "$FMK_ROOT/tests/lean"
FMK_PIN=$(cat lean-toolchain)
test "$FMK_PIN" = leanprover/lean4:v4.34.0-rc2
elan toolchain install "$FMK_PIN"
elan run "$FMK_PIN" lean --version | grep -F 'Lean (version 4.34.0-rc2,'
elan run "$FMK_PIN" lake --version | grep -F '(Lean version 4.34.0-rc2)'
export LAKE_ARTIFACT_CACHE=false LAKE_RESTORE_ARTIFACTS=false
export MATHLIB_CACHE_GET_URL=https://cache.mathlib.org/mathlib4-master
FMK_PINS=$(sha256sum lean-toolchain lakefile.toml lake-manifest.json)
elan run "$FMK_PIN" lake --no-cache exe cache get
test "$FMK_PINS" = "$(sha256sum lean-toolchain lakefile.toml lake-manifest.json)"
