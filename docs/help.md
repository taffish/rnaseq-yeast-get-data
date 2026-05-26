taf-rnaseq-yeast-get-data 0.1.0-r1

Prepare the local yeast SNF2 RNA-seq formal test dataset for TAFFISH
RNA-seq flow validation.

Flow family role:
  This is a maintainer data-preparation flow, not an RNA-seq analysis subflow.
  It prepares the central formal data consumed by RNA-seq subflow tests and
  future rnaseq-standard-flow validation. Analysis flows should consume the
  prepared local data and should not download these resources at normal
  runtime.

Usage:
  taf-rnaseq-yeast-get-data --outdir OUTDIR [options]

Wrapper options:
  -h, --help       Show this help
  -v, --version    Show TAFFISH package version
  --compile        Print generated shell code instead of running it
  --               Stop wrapper option parsing

Required options:
  -o, --outdir DIR
      Single output directory. All generated files are written under DIR.

Common options:
  --stage plan|metadata|counts|reference|genesets|fastq|all
      Which preparation stage to run.
      Default: plan

      plan      Write selected replicate table, URL table, methods,
                manifest and download plan. No network download.
      metadata  Download small ENA/author metadata files and build
                source accession/sample tables.
      counts    Download author count tarballs and build a selected
                12-vs-12 count matrix.
      reference Download the SGD S288C R64.4.1 reference tarball,
                validate it, extract feature-only gene GFF3 and derive
                genome FASTA from the GFF3 embedded FASTA block.
      genesets Build SGD GO-derived GMT files and a yeast background gene
                list for enrichment formal tests.
      fastq     Download ENA lane FASTQs, verify md5, merge lanes by
                biological sample and sample reads with SeqKit.
      all       Run metadata, counts, reference, genesets and fastq.

  --reads-per-sample N
      Reads sampled per biological sample in the FASTQ package.
      Default: 500000

  --seed N
      SeqKit random seed used during FASTQ sampling.
      Default: 20260522

  -t, --threads N
      Reserved for tool steps that can use threads.
      Default: 4

  --limit-samples N
      For fastq stage trials, process only the first N biological
      samples from the selected sample list. Use 0 for all samples.
      Default: 0

  --resume true|false
      Allow reusing an existing output directory and existing files.
      Use this when continuing from plan to metadata/counts/fastq, or
      when continuing after a partial FASTQ trial.
      Default: false

  --force true|false
      Allow overwriting existing files inside OUTDIR. This does not
      delete OUTDIR.
      Default: false

  --keep-lanes true|false
      Keep downloaded lane FASTQs and merged temporary FASTQs under
      OUTDIR/02_intermediate/. By default they are removed after each
      sampled FASTQ is written.
      Default: false

Examples:
  ./scripts/run-streaming.sh --outdir yeast-snf2-data-v1

  ./scripts/run-streaming.sh \
    --outdir yeast-snf2-data-v1 \
    --stage metadata \
    --resume true

  ./scripts/run-streaming.sh \
    --outdir yeast-snf2-data-v1 \
    --stage fastq \
    --resume true \
    --limit-samples 1

  ./scripts/run-streaming.sh \
    --outdir yeast-snf2-data-v1 \
    --stage reference \
    --resume true

  ./scripts/run-streaming.sh \
    --outdir yeast-snf2-data-v1 \
    --stage genesets \
    --resume true

  ./scripts/run-streaming.sh \
    --outdir yeast-snf2-data-v1 \
    --stage all \
    --resume true

Resume behavior:
  Existing OUTDIR is rejected by default to avoid accidental overwrite.
  To continue in the same directory, use --resume true. Existing final
  sample FASTQs are reused after gzip checks, and lane FASTQs are reused
  only when size/md5 checks pass. To intentionally redownload or overwrite
  existing files inside OUTDIR, use --force true.

Outputs:
  OUTDIR/00_inputs/
      selected_replicates.tsv and source_urls.tsv

  OUTDIR/03_results/yeast-snf2-fastq-mini-v1/
      samples.tsv, generated_samples.tsv, metadata.tsv,
      source_accessions.tsv, reads/*.fq.gz and expected/fastq_stats.tsv

  OUTDIR/03_results/yeast-snf2-counts-medium-v1/
      source files and counts/gene_counts_12v12.tsv

  OUTDIR/03_results/yeast-reference-sgd-r64.4.1-v1/
      reference/genome/yeast_s288c_reference_genome_R64-4-1.fa
      reference/genome/yeast_s288c_reference_genome_R64-4-1.fa.fai
      reference/annotation/yeast_s288c_gene_annotation_R64-4-1.gff3
      source files, source_files.tsv, reference_summary.tsv and manifest.json

  OUTDIR/03_results/yeast-sgd-go-gene-sets-r64.4.1-v1/
      gene_sets/sgd_go_bp.gmt
      gene_sets/sgd_go_mf.gmt
      gene_sets/sgd_go_cc.gmt
      gene_sets/sgd_go_all.gmt
      background/yeast_background_genes.tsv
      metadata files, source_files.tsv, gene_sets_summary.tsv and manifest.json

  OUTDIR/04_reports/
      commands.sh, versions.tsv, methods.txt, download-plan.md,
      flow_summary.tsv and checksums.tsv

Progress:
  After the main shell flow starts, stage, sample, lane, download, md5,
  merge, sampling and cleanup status are printed to stdout and appended
  to OUTDIR/01_logs/flow.log. Curl downloads use a progress bar when data
  are fetched.

  For long local data acquisition, prefer ./scripts/run-streaming.sh from
  this app directory. It compiles src/main.taf to a temporary shell script
  and runs it directly, so output is streamed immediately. Some local
  taf run builds buffer child output until the process exits.

Network resume:
  If an ENA HTTPS transfer fails, rerun with --resume true. Completed
  lane FASTQs are reused after size/md5 checks; corrupt cached lane files
  are removed and downloaded once more. Partial .tmp downloads are resumed
  with curl -C - when possible.

Boundaries:
  This is a maintainer data-preparation helper. It intentionally
  downloads public external data when metadata, counts, reference,
  genesets, fastq or all is requested. The default plan stage performs no
  network download. RNA-seq analysis flows should consume the prepared local
  data and should not download it at normal runtime.

  The reference stage prepares genome FASTA and gene annotation GFF3, but
  does not build transcript or aligner indexes. The genesets stage prepares
  GO-derived GMT/background resources for enrichment tests. The genome FASTA is derived from the GFF3
  embedded FASTA block so sequence IDs match annotation seqids for tools
  such as gffread. The annotation output is feature-only; the embedded
  FASTA block is stripped before writing the final GFF3.
