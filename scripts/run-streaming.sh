#!/bin/sh
set -eu

APP_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMPDIR_ROOT="${TMPDIR:-/tmp}"
RUN_DIR="$(mktemp -d "${TMPDIR_ROOT%/}/rnaseq-yeast-get-data-run.XXXXXX")"
RUN_SH="${RUN_DIR}/run.sh"

cleanup() {
    rm -rf "$RUN_DIR"
}
trap cleanup EXIT INT TERM HUP

cd "$APP_ROOT"
taf compile src/main.taf -- "$@" > "$RUN_SH"
chmod +x "$RUN_SH"
sh "$RUN_SH"
