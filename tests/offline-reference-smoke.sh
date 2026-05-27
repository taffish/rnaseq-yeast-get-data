#!/bin/sh
set -eu

APP_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/rnaseq-yeast-reference-smoke.XXXXXX")"
BIN_DIR="${TMPROOT}/bin"
SRC_DIR="${TMPROOT}/src"
OUTDIR="${TMPROOT}/out"
REF_DIR="${SRC_DIR}/S288C_reference_genome_R64-4-1_20230830"
REF_PKG="${OUTDIR}/03_results/yeast-reference-sgd-r64.4.1-v1"

cleanup() {
    rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM HUP

mkdir -p "$BIN_DIR" "$REF_DIR" "${REF_PKG}/source"

cat > "$BIN_DIR/taf-seqkit-v2.13.0-r2" <<'EOF'
#!/bin/sh
set -eu

sq() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

emit_compiled() {
    self="$(command -v taf-seqkit-v2.13.0-r2)"
    printf '#!/bin/sh\n'
    printf 'set -eu\n'
    printf '%s' "$(sq "$self")"
    for arg in "$@"; do
        case "$arg" in
            *'$'*|*'"'*|*'*'*)
                printf ' %s' "$arg"
                ;;
            *)
                printf ' %s' "$(sq "$arg")"
                ;;
        esac
    done
    printf '\n'
}

if [ "${1:-}" = "--compile" ]; then
    shift
    emit_compiled "$@"
    exit 0
fi

[ "${1:-}" = "seqkit" ] || exit 2
[ "${2:-}" = "version" ] || exit 2
printf '%s\n' 'seqkit v2.13.0'
EOF
chmod +x "$BIN_DIR/taf-seqkit-v2.13.0-r2"

{
    printf '%s\n' '>ref|NC_001133| synthetic raw RefSeq-style chromosome I'
    printf '%s\n' 'ACGTACGTACGT'
    printf '%s\n' '>ref|NC_001134| synthetic raw RefSeq-style chromosome II'
    printf '%s\n' 'TTTTCCCCAAAA'
} | gzip -c > "${REF_DIR}/S288C_reference_sequence_R64-4-1_20230830.fsa.gz"

{
    printf '%s\n' '##gff-version 3'
    printf '%s\n' 'chrI	SGD	gene	1	12	.	+	.	ID=gene:YAL001C;Name=TFC3'
    printf '%s\n' 'chrI	SGD	mRNA	1	12	.	+	.	ID=transcript:YAL001C_mRNA;Parent=gene:YAL001C'
    printf '%s\n' '##FASTA'
    printf '%s\n' '>chrI'
    printf '%s\n' 'ACGTACGTACGT'
    printf '%s\n' '>chrII'
    printf '%s\n' 'TTTTCCCCAAAA'
} | gzip -c > "${REF_DIR}/saccharomyces_cerevisiae_R64-4-1_20230830.gff.gz"

tar -czf "${REF_PKG}/source/S288C_reference_genome_R64-4-1_20230830.tgz" \
    -C "$SRC_DIR" \
    S288C_reference_genome_R64-4-1_20230830

PATH="$BIN_DIR:$PATH" "$APP_ROOT/scripts/run-streaming.sh" \
    --outdir "$OUTDIR" \
    --stage reference \
    --resume true

GENOME="${REF_PKG}/reference/genome/yeast_s288c_reference_genome_R64-4-1.fa"
GENOME_FAI="${GENOME}.fai"
GFF="${REF_PKG}/reference/annotation/yeast_s288c_gene_annotation_R64-4-1.gff3"

test -s "$GENOME"
test -s "$GENOME_FAI"
test -s "$GFF"
grep -q '^>chrI' "$GENOME"
grep -q '^chrI	' "$GENOME_FAI"
if grep -q '^>ref|NC_' "$GENOME"; then
    exit 1
fi
grep -q 'ID=gene:YAL001C' "$GFF"
if grep -q '^##FASTA' "$GFF"; then
    exit 1
fi
if grep -q '^>chrI' "$GFF"; then
    exit 1
fi

if gzip -t "$GENOME" >/dev/null 2>&1; then
    exit 1
fi
if gzip -t "$GFF" >/dev/null 2>&1; then
    exit 1
fi

test -s "${REF_PKG}/source_files.tsv"
test -s "${REF_PKG}/reference_summary.tsv"
test -s "${REF_PKG}/manifest.json"
grep -q 'saccharomyces_cerevisiae_R64-4-1_20230830.gff.gz' "${REF_PKG}/source_files.tsv"
grep -q 'embedded_fasta' "${REF_PKG}/source_files.tsv"
grep -q 'generated_fai' "${REF_PKG}/source_files.tsv"
grep -q 'genome_fai	reference/genome/yeast_s288c_reference_genome_R64-4-1.fa.fai' "${REF_PKG}/reference_summary.tsv"
grep -q 'genome_source	embedded_fasta_from_annotation_gff3' "${REF_PKG}/reference_summary.tsv"
grep -q 'raw_genome_member	.*S288C_reference_sequence_R64-4-1_20230830.fsa.gz' "${REF_PKG}/reference_summary.tsv"
grep -q 'annotation_source	features_before_embedded_fasta' "${REF_PKG}/reference_summary.tsv"
grep -q 'reference_genome	present' "${OUTDIR}/04_reports/flow_summary.tsv"
grep -q 'reference_annotation	present' "${OUTDIR}/04_reports/flow_summary.tsv"

find "$OUTDIR/03_results" -type f \( -name '*.fa' -o -name '*.fasta' -o -name '*.fna' \) \
    | grep -Ei 'genome|reference|s288c|r64|yeast' >/dev/null
find "$OUTDIR/03_results" -type f \( -name '*.gff3' -o -name '*.gff' -o -name '*.gtf' \) \
    | grep -Ei 'gene|annotation|s288c|r64|yeast' >/dev/null
