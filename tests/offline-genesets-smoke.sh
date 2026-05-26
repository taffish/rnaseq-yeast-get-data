#!/bin/sh
set -eu

APP_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP_BASE="${TMPDIR:-/tmp}"
RUN_DIR="$(mktemp -d "${TMP_BASE%/}/rnaseq-yeast-genesets-smoke.XXXXXX")"

cleanup() {
    rm -rf "$RUN_DIR"
}
trap cleanup EXIT INT TERM HUP

OUTDIR="$RUN_DIR/out"
REF_PKG="$OUTDIR/03_results/yeast-reference-sgd-r64.4.1-v1"
COUNT_PKG="$OUTDIR/03_results/yeast-snf2-counts-medium-v1"
GENESETS_PKG="$OUTDIR/03_results/yeast-sgd-go-gene-sets-r64.4.1-v1"

mkdir -p \
    "$REF_PKG/reference/annotation" \
    "$COUNT_PKG/counts" \
    "$GENESETS_PKG/source"

cat > "$REF_PKG/reference/annotation/yeast_s288c_gene_annotation_R64-4-1.gff3" <<'EOF'
##gff-version 3
chrI	SGD	gene	1	100	.	+	.	ID=YAL001C;Name=YAL001C;Ontology_term=GO:0000001,GO:0003674,SO:0000704
chrI	SGD	gene	201	300	.	+	.	ID=YAL002W;Name=YAL002W;Ontology_term=GO:0000001,GO:0000002,GO:0008150,SO:0000704
chrI	SGD	gene	401	500	.	-	.	ID=YAL003W;Name=YAL003W;Ontology_term=GO:0000003,GO:0005575,SO:0000704
EOF

cat > "$COUNT_PKG/counts/gene_counts_12v12.tsv" <<'EOF'
gene_id	WT_01	SNF2KO_01
YAL001C	10	20
YAL002W	30	40
YAL003W	50	60
ambiguous	1	1
alignment_not_unique	2	2
EOF

cat > "$GENESETS_PKG/source/go-basic.obo" <<'EOF'
format-version: 1.2

[Term]
id: GO:0000001
name: mitochondrion inheritance
namespace: biological_process

[Term]
id: GO:0000002
name: mitochondrial genome maintenance
namespace: molecular_function

[Term]
id: GO:0000003
name: reproduction
namespace: cellular_component

[Term]
id: GO:9999999
name: obsolete example
namespace: biological_process
is_obsolete: true
EOF

"$APP_ROOT/scripts/run-streaming.sh" \
    --outdir "$OUTDIR" \
    --stage genesets \
    --resume true

test -s "$GENESETS_PKG/gene_sets/sgd_go_bp.gmt"
test -s "$GENESETS_PKG/gene_sets/sgd_go_mf.gmt"
test -s "$GENESETS_PKG/gene_sets/sgd_go_cc.gmt"
test -s "$GENESETS_PKG/gene_sets/sgd_go_all.gmt"
test -s "$GENESETS_PKG/background/yeast_background_genes.tsv"
test -s "$GENESETS_PKG/metadata/go_terms.tsv"
test -s "$GENESETS_PKG/metadata/gene_go_terms.tsv"
test -s "$GENESETS_PKG/metadata/gene_set_index.tsv"
test -s "$GENESETS_PKG/source_files.tsv"
test -s "$GENESETS_PKG/gene_sets_summary.tsv"
test -s "$GENESETS_PKG/manifest.json"

grep -q '^GO:0000001	mitochondrion inheritance \[biological_process\]	YAL001C	YAL002W$' "$GENESETS_PKG/gene_sets/sgd_go_bp.gmt"
grep -q '^GO:0000002	mitochondrial genome maintenance \[molecular_function\]	YAL002W$' "$GENESETS_PKG/gene_sets/sgd_go_mf.gmt"
grep -q '^GO:0000003	reproduction \[cellular_component\]	YAL003W$' "$GENESETS_PKG/gene_sets/sgd_go_cc.gmt"
grep -q '^YAL001C$' "$GENESETS_PKG/background/yeast_background_genes.tsv"
grep -q '^YAL003W$' "$GENESETS_PKG/background/yeast_background_genes.tsv"
if grep -q '^ambiguous$' "$GENESETS_PKG/background/yeast_background_genes.tsv"; then
    exit 1
fi
if grep -q 'GO:0008150' "$GENESETS_PKG/gene_sets/sgd_go_all.gmt"; then
    exit 1
fi
grep -q 'background_genes	3' "$GENESETS_PKG/gene_sets_summary.tsv"
grep -q 'gene_sets	present' "$OUTDIR/04_reports/flow_summary.tsv"

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$GENESETS_PKG/manifest.json" >/dev/null
fi
