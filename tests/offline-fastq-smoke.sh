#!/bin/sh
set -eu

APP_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/rnaseq-yeast-fastq-smoke.XXXXXX")"
BIN_DIR="${TMPROOT}/bin"
LANE_DIR="${TMPROOT}/lanes"
OUTDIR="${TMPROOT}/out"

cleanup() {
    rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM HUP

mkdir -p "$BIN_DIR" "$LANE_DIR" "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1"

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
cmd="${2:-}"
shift 2

case "$cmd" in
    version)
        printf '%s\n' 'seqkit v2.13.0'
        ;;
    sample)
        cat >/dev/null
        n=""
        out=""
        input=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -2)
                    shift
                    ;;
                -s|-n|-o)
                    opt="$1"
                    val="$2"
                    shift 2
                    case "$opt" in
                        -n) n="$val" ;;
                        -o) out="$val" ;;
                    esac
                    ;;
                *)
                    input="$1"
                    shift
                    ;;
            esac
        done
        [ -n "$n" ] || exit 3
        [ -n "$out" ] || exit 3
        [ -n "$input" ] || exit 3
        gzip -dc "$input" | awk -v n="$n" 'NR <= n * 4 { print }' | gzip -c > "$out"
        ;;
    stats)
        printf 'file\tformat\ttype\tnum_seqs\tsum_len\tmin_len\tavg_len\tmax_len\n'
        for f in "$@"; do
            [ "$f" = "-T" ] && continue
            [ -f "$f" ] || continue
            lines="$(gzip -dc "$f" | wc -l | awk '{print $1}')"
            reads="$((lines / 4))"
            printf '%s\tFASTQ\tDNA\t%s\t%s\t%s\t%s\t%s\n' "$f" "$reads" "$reads" 1 1 1
        done
        ;;
    *)
        exit 2
        ;;
esac
EOF
chmod +x "$BIN_DIR/taf-seqkit-v2.13.0-r2"

make_lane() {
    out="$1"
    start="$2"
    end="$3"
    {
        i="$start"
        while [ "$i" -le "$end" ]; do
            printf '@r%s\nACGTACGTACGT\n+\nFFFFFFFFFFFF\n' "$i"
            i="$((i + 1))"
        done
    } | gzip -c > "$out"
}

make_lane "$LANE_DIR/lane1.fq.gz" 1 6
make_lane "$LANE_DIR/lane2.fq.gz" 7 12
make_lane "$LANE_DIR/lane3.fq.gz" 13 18
make_lane "$LANE_DIR/lane4.fq.gz" 19 24
printf '%s\n' 'primary source is intentionally wrong' | gzip -c > "$LANE_DIR/lane3.primary-bad.fq.gz"

md5_one() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$1" | awk '{print $1}'
    else
        md5 -q "$1"
    fi
}

lane1_md5="$(md5_one "$LANE_DIR/lane1.fq.gz")"
lane2_md5="$(md5_one "$LANE_DIR/lane2.fq.gz")"
lane3_md5="$(md5_one "$LANE_DIR/lane3.fq.gz")"
lane4_md5="$(md5_one "$LANE_DIR/lane4.fq.gz")"
lane1_bytes="$(wc -c < "$LANE_DIR/lane1.fq.gz" | awk '{print $1}')"
lane2_bytes="$(wc -c < "$LANE_DIR/lane2.fq.gz" | awk '{print $1}')"
lane3_bytes="$(wc -c < "$LANE_DIR/lane3.fq.gz" | awk '{print $1}')"
lane4_bytes="$(wc -c < "$LANE_DIR/lane4.fq.gz" | awk '{print $1}')"

cat > "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/source_accessions.tsv" <<EOF
sample_id	condition	source_condition	source_biol_rep	selected_order	lane	run_accession	fastq_url	fastq_md5	fastq_bytes	fallback_url	fallback_md5	fallback_bytes	fallback_kind
TINY_01	test	TEST	1	1	1	LANE1	file://${LANE_DIR}/lane1.fq.gz	${lane1_md5}	${lane1_bytes}	.	.	.	.
TINY_01	test	TEST	1	1	2	LANE2	file://${LANE_DIR}/lane2.fq.gz	${lane2_md5}	${lane2_bytes}	.	.	.	.
TINY_02	test	TEST	2	2	1	LANE3	file://${LANE_DIR}/lane3.primary-bad.fq.gz	${lane3_md5}	${lane3_bytes}	file://${LANE_DIR}/lane3.fq.gz	${lane3_md5}	${lane3_bytes}	submitted_ftp
TINY_02	test	TEST	2	2	2	LANE4	file://${LANE_DIR}/lane4.fq.gz	${lane4_md5}	${lane4_bytes}	.	.	.	.
EOF

PATH="$BIN_DIR:$PATH" "$APP_ROOT/scripts/run-streaming.sh" \
    --outdir "$OUTDIR" \
    --stage fastq \
    --resume true \
    --reads-per-sample 5

for sid in TINY_01 TINY_02; do
    FASTQ="$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/reads/${sid}.fq.gz"
    test -s "$FASTQ"
    gzip -t "$FASTQ"

    read_count="$(gzip -dc "$FASTQ" | awk 'END { print NR / 4 }')"
    test "$read_count" = "5"
done

grep -q 'Using gzip-member concatenation' "$OUTDIR/01_logs/flow.log"
grep -q 'Sampled gzip OK: TINY_01' "$OUTDIR/01_logs/flow.log"
grep -q 'Sampled gzip OK: TINY_02' "$OUTDIR/01_logs/flow.log"
grep -q 'Primary FASTQ source failed for LANE3' "$OUTDIR/01_logs/flow.log"
grep -q 'Fallback FASTQ source succeeded for LANE3: submitted_ftp' "$OUTDIR/01_logs/flow.log"
test -s "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/expected/fastq_stats.tsv"
test -s "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/source_downloads.tsv"
grep -q '^TINY_02	LANE3	.*	submitted_ftp	.*	true	primary failed; fallback succeeded$' "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/source_downloads.tsv"

PATH="$BIN_DIR:$PATH" "$APP_ROOT/scripts/run-streaming.sh" \
    --outdir "$OUTDIR" \
    --stage fastq \
    --resume true \
    --reads-per-sample 5

grep -q 'Sample already complete; skip lane download for TINY_01' "$OUTDIR/01_logs/flow.log"
grep -q 'Sample already complete; skip lane download for TINY_02' "$OUTDIR/01_logs/flow.log"
generated_count="$(awk 'NR > 1 { n++ } END { print n + 0 }' "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/generated_samples.tsv")"
test "$generated_count" = "2"

rm -f "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/reads/TINY_02.fq.gz"
mkdir -p "$OUTDIR/02_intermediate/cache/lanes/TINY_02"
dd if=/dev/zero of="$OUTDIR/02_intermediate/cache/lanes/TINY_02/LANE4.fastq.gz" bs="$lane4_bytes" count=1 >/dev/null 2>&1

PATH="$BIN_DIR:$PATH" "$APP_ROOT/scripts/run-streaming.sh" \
    --outdir "$OUTDIR" \
    --stage fastq \
    --resume true \
    --reads-per-sample 5

grep -q 'FASTQ verification failed for LANE4 from fastq_ftp; remove cached file and redownload once' "$OUTDIR/01_logs/flow.log"
grep -q 'FASTQ source OK for LANE4: fastq_ftp' "$OUTDIR/01_logs/flow.log"
grep -q 'Sample already complete; skip lane download for TINY_01' "$OUTDIR/01_logs/flow.log"
test -s "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/reads/TINY_02.fq.gz"
gzip -t "$OUTDIR/03_results/yeast-snf2-fastq-mini-v1/reads/TINY_02.fq.gz"
grep -q 'LANE4.fastq.gz' "$OUTDIR/04_reports/commands.sh"
if grep -q 'LANE1.fastq.gz' "$OUTDIR/04_reports/commands.sh"; then
    exit 1
fi
