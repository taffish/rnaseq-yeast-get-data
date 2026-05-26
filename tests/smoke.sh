#!/bin/sh
set -eu

export TAFFISH_CONTAINER_BACKEND="${TAFFISH_CONTAINER_BACKEND:-podman}"

APP_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUTDIR="${APP_ROOT}/target/smoke-rnaseq-yeast-get-data"

rm -rf "$OUTDIR"
"$APP_ROOT/scripts/run-streaming.sh" --outdir "$OUTDIR" --stage plan

test -s "$OUTDIR/00_inputs/selected_replicates.tsv"
test -s "$OUTDIR/00_inputs/source_urls.tsv"
test -s "$OUTDIR/04_reports/download-plan.md"
test -s "$OUTDIR/04_reports/commands.sh"
test -s "$OUTDIR/04_reports/versions.tsv"
test -s "$OUTDIR/04_reports/methods.txt"
test -s "$OUTDIR/run.manifest.json"

test "$(awk 'NR>1{n++} END{print n+0}' "$OUTDIR/00_inputs/selected_replicates.tsv")" = "24"
grep -q 'sgd_reference_tarball' "$OUTDIR/00_inputs/source_urls.tsv"
grep -q 'yeast-reference-sgd-r64.4.1-v1' "$OUTDIR/04_reports/download-plan.md"
grep -q 'reference_package' "$OUTDIR/run.manifest.json"

find "$OUTDIR" -name '*.fq.gz' | grep . && exit 1
"$APP_ROOT/tests/offline-reference-smoke.sh"
"$APP_ROOT/tests/offline-genesets-smoke.sh"
exit 0
