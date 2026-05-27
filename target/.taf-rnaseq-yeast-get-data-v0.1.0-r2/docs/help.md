taf-rnaseq-yeast-get-data 0.1.0-r2

Purpose:
  Prepare the local yeast SNF2 RNA-seq formal test dataset used by TAFFISH
  RNA-seq flow validation. The flow can write the selected sample/accession
  plan, download and assemble author count matrices, prepare the SGD S288C
  R64.4.1 reference, build SGD GO-derived gene sets, and acquire sampled ENA
  FASTQ files with logs, checksums, methods, and provenance.

Flow family role:
  This is a maintainer data-preparation flow, not an RNA-seq analysis subflow.
  It intentionally downloads public ENA, SGD, Gene Ontology, and author count
  resources for formal test-data preparation. The default plan stage performs
  no network download. Analysis flows should consume the prepared local data
  and should not download these resources at normal runtime.

Usage:
  taf-rnaseq-yeast-get-data \
    --outdir yeast-snf2-data-v1 \
    [options]

Required output:
  --outdir PATH, -o PATH
      Dedicated output directory. Existing directories are refused unless
      --resume true or --force true is set.

Common options:
  --stage plan|metadata|counts|reference|genesets|fastq|all
      Preparation stage to run. Default: plan.

      plan
          Write selected replicate table, URL table, methods, manifest, and
          download plan. No network download.

      metadata
          Download small ENA/author metadata files and build source accession
          and sample tables.

      counts
          Download author count tarballs and build the selected 12-vs-12 gene
          count matrix.

      reference
          Download the SGD S288C R64.4.1 reference tarball, validate it,
          extract feature-only gene GFF3, and derive genome FASTA from the
          embedded GFF3 FASTA block.

      genesets
          Build SGD GO-derived BP/MF/CC/all GMT files and a yeast background
          gene list for enrichment formal tests.

      fastq
          Download ENA lane FASTQs, verify size/gzip/md5, retry corrupt cache
          files once, use submitted_ftp fallback when primary fastq_ftp fails,
          merge lanes by biological sample, and sample reads with SeqKit.

      all
          Run metadata, counts, reference, genesets, and fastq.

  --reads-per-sample N
      Reads sampled per biological sample in the FASTQ package.
      Default: 500000.

  --seed N
      SeqKit random seed used during FASTQ sampling. Default: 20260522.

  --threads N, -t N
      Reserved for tool steps that can use threads. Default: 4.

  --limit-samples N
      For FASTQ acquisition trials, process only the first N biological
      samples from the selected sample list. Use 0 for all samples.
      Default: 0.

  --resume true|false
      Allow reusing an existing output directory and existing files. Use this
      when continuing from plan to metadata/counts/reference/genesets/fastq,
      or when continuing after a partial FASTQ run. Default: false.

  --force true|false
      Allow overwriting existing files inside --outdir. This does not delete
      --outdir. Default: false.

  --keep-lanes true|false
      Keep downloaded lane FASTQs and merged temporary FASTQs under
      <outdir>/02_intermediate/. By default they are removed after each sampled
      FASTQ is written. Default: false.

Examples:
  Write the offline download plan:
    taf-rnaseq-yeast-get-data \
      --outdir yeast-snf2-data-v1

  Build metadata tables:
    taf-rnaseq-yeast-get-data \
      --outdir yeast-snf2-data-v1 \
      --stage metadata \
      --resume true

  Trial one biological sample through FASTQ acquisition:
    taf-rnaseq-yeast-get-data \
      --outdir yeast-snf2-data-v1 \
      --stage fastq \
      --resume true \
      --limit-samples 1

  Prepare all central yeast formal test resources:
    taf-rnaseq-yeast-get-data \
      --outdir yeast-snf2-data-v1 \
      --stage all \
      --resume true

Output tree:
  <outdir>/00_inputs/selected_replicates.tsv
  <outdir>/00_inputs/source_urls.tsv
  <outdir>/01_logs/flow.log
  <outdir>/03_results/yeast-snf2-fastq-mini-v1/samples.tsv
  <outdir>/03_results/yeast-snf2-fastq-mini-v1/generated_samples.tsv
  <outdir>/03_results/yeast-snf2-fastq-mini-v1/metadata.tsv
  <outdir>/03_results/yeast-snf2-fastq-mini-v1/source_accessions.tsv
  <outdir>/03_results/yeast-snf2-fastq-mini-v1/source_downloads.tsv
  <outdir>/03_results/yeast-snf2-fastq-mini-v1/reads/*.fq.gz
  <outdir>/03_results/yeast-snf2-fastq-mini-v1/expected/fastq_stats.tsv
  <outdir>/03_results/yeast-snf2-counts-medium-v1/counts/gene_counts_12v12.tsv
  <outdir>/03_results/yeast-reference-sgd-r64.4.1-v1/reference/genome/
  <outdir>/03_results/yeast-reference-sgd-r64.4.1-v1/reference/annotation/
  <outdir>/03_results/yeast-sgd-go-gene-sets-r64.4.1-v1/gene_sets/
  <outdir>/03_results/yeast-sgd-go-gene-sets-r64.4.1-v1/background/
  <outdir>/04_reports/commands.sh
  <outdir>/04_reports/versions.tsv
  <outdir>/04_reports/methods.txt
  <outdir>/04_reports/download-plan.md
  <outdir>/04_reports/flow_summary.tsv
  <outdir>/04_reports/checksums.tsv
  <outdir>/run.manifest.json

FASTQ fallback and resume:
  r2 requests ENA submitted_ftp, submitted_md5, and submitted_bytes metadata in
  addition to primary fastq_ftp fields. If cached r1 metadata lacks these
  fallback columns, --resume true refreshes the small metadata table before
  FASTQ acquisition. Existing final sample FASTQs are reused after gzip checks.
  Lane FASTQs are reused only when size, gzip, and md5 checks pass. Corrupt
  cached lane files are removed and downloaded once more.

  If primary ENA fastq_ftp returns an invalid object and ENA provides
  submitted_ftp for the same run accession, r2 tries that fallback source and
  records the actual source, validation status, and fallback_used flag in:

    <outdir>/03_results/yeast-snf2-fastq-mini-v1/source_downloads.tsv

Maintainer streaming helper:
  For long local data acquisition, maintainers may prefer:

    ./scripts/run-streaming.sh --outdir yeast-snf2-data-v1 --stage all

  from this app directory. The helper compiles src/main.taf to a temporary
  shell script and runs it directly, so output is streamed immediately. The
  public flow interface remains taf-rnaseq-yeast-get-data.

Dependencies:
  taf-seqkit 2.13.0-r2

Boundaries:
  This flow prepares local formal test data for TAFFISH RNA-seq flow
  development and validation. It is not intended for user RNA-seq analysis,
  does not build transcript or aligner indexes, and does not replace the
  RNA-seq analysis subflows. The reference stage writes genome FASTA and
  feature-only gene annotation GFF3. The genesets stage uses direct SGD GO
  annotations and does not perform GO ancestor propagation.

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
