#!/bin/sh
# Build Nuclear Land (the PRG and its game disk) and start it in VICE.
# Uses $X64SC if set, else x64sc on the PATH, else the VICE install the tests use.
set -e
cd "$(dirname "$0")"
NL="$PWD"

X64SC="${X64SC:-$(command -v x64sc || true)}"
X64SC="${X64SC:-/Applications/vice-arm64-gtk3-3.10/bin/x64sc}"
[ -x "$X64SC" ] || { echo "x64sc not found: install VICE or set X64SC=/path/to/x64sc" >&2; exit 1; }
command -v acme >/dev/null || { echo "acme not found: install the ACME assembler" >&2; exit 1; }

mkdir -p build
acme -f cbm -o build/nland.prg main.asm
python3 tools/make_disk.py >/dev/null        # build/nland.d64: the game plus one portrait per person

# PAL (the game is PAL-only); an absolute path, because the macOS wrapper starts VICE elsewhere
exec "$X64SC" -pal -autostart "$NL/build/nland.d64"
