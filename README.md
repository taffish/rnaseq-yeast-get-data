# rnaseq-yeast-get-data

`rnaseq-yeast-get-data` is a TAFFISH-maintained data-preparation flow for the local RNA-seq formal test dataset:

- source project: ENA / BioProject `PRJEB5348`
- biology: *Saccharomyces cerevisiae* WT vs `snf2` knockout
- selected design: 12 WT + 12 `snf2_KO` biological samples
- FASTQ target: 500k single-end reads per biological sample, with per-lane ENA `submitted_ftp` fallback when the primary `fastq_ftp` object fails validation
- count target: author-derived 12-vs-12 gene count matrix
- reference target: SGD S288C `R64.4.1` chr-style genome FASTA and feature-only gene annotation GFF3
- gene-set target: SGD GO-derived GMT files and count-matrix background genes for enrichment tests

This app is intentionally kept under `repos/apps/bio/flows/rna-seq/test-data/yeast/`. It prepares the central local maintainer data for validating the RNA-seq flow line; generated real-mini data should be consumed from this shared test-data tree rather than copied into individual subflow app repositories.

## Role in the RNA-seq Flow Set

`rnaseq-yeast-get-data` is a maintainer data-preparation flow, not an analysis
subflow. It exists to prepare the central formal-test data consumed by
`rnaseq-index-flow`, `rnaseq-expression-flow`, `rnaseq-alignment-flow`,
`rnaseq-count-flow`, `rnaseq-alignment-qc-flow`, `rnaseq-de-flow`,
`rnaseq-enrichment-flow`, and `rnaseq-report-flow`.

The analysis subflows and the future `rnaseq-standard-flow` should use the
prepared local data through `TAFFISH_RNASEQ_TESTDATA` or the default
`test-data/yeast/data/03_results` tree. They should not download ENA, SGD, GO,
or author-count resources during normal analysis runtime.

## Identity

- name: `rnaseq-yeast-get-data`
- command: `taf-rnaseq-yeast-get-data`
- kind: `flow`
- TAFFISH version: `0.1.0-r2`
- upstream dataset: `PRJEB5348` plus `bartongroup/profDGE48` commit `375dc0d57d9d1fa96a4245a6530e0fda34305891`; SGD S288C reference genome `R64.4.1`
- dependencies: `taf-seqkit 2.13.0-r2`

## Data Sources, Licenses and Citation

This repository is the canonical TAFFISH provenance record for the yeast SNF2
example data used by the RNA-seq flow family. The generated files are
demonstration and validation artifacts derived from public biological resources;
users should cite the original study and follow the current terms of the source
databases when reusing the data or reports.

| Component | Used for | Source | Version, accession or commit | Attribution and terms |
| --- | --- | --- | --- | --- |
| Raw RNA-seq reads and run metadata | Lane FASTQs, sample table, FASTQ-derived reference and de novo example reports | ENA / NCBI BioProject [`PRJEB5348`](https://www.ebi.ac.uk/ena/browser/view/PRJEB5348) | Highly Replicated Yeast RNAseq, WT vs `snf2` knockout | Cite the accession and the original study: Gierlinski et al. 2015, Bioinformatics, DOI [`10.1093/bioinformatics/btv425`](https://doi.org/10.1093/bioinformatics/btv425). Follow ENA/EMBL-EBI and NCBI public data usage terms. |
| Author metadata and count files | ENA sample mapping, excluded-replicate list, selected WT/Snf2 count matrix | [`bartongroup/profDGE48`](https://github.com/bartongroup/profDGE48) | Commit `375dc0d57d9d1fa96a4245a6530e0fda34305891` | Cite the upstream repository/commit together with the associated yeast RNA-seq study. Check the upstream repository for current licensing and reuse notes before redistribution. |
| Reference genome and annotation | Reference-mode genome FASTA and feature-only GFF3 for index construction and formal tests | Saccharomyces Genome Database archive | S288C `R64.4.1`, archive tarball `S288C_reference_genome_R64-4-1_20230830.tgz` | Attribute SGD / yeastgenome.org. SGD materials are distributed under Creative Commons Attribution 4.0 according to SGD documentation and publications. |
| Gene Ontology terms | GO names, namespaces and term metadata used while building GMT files | Gene Ontology [`go-basic.obo`](https://current.geneontology.org/ontology/go-basic.obo) | Current OBO snapshot downloaded at preparation time | Attribute the Gene Ontology Consortium and follow current GO resource terms. The generated GMTs combine GO terms with SGD annotation-derived gene-to-GO mappings. |
| TAFFISH generated derivatives | Sampled FASTQs, selected count matrix, reference package, GO-derived GMT/background, checksums and reports | This flow output | Recorded in `run.manifest.json`, `source_urls.tsv`, `source_downloads.tsv`, `checksums.tsv` and package manifests | Treat these as reproducible demonstration artifacts. Keep the provenance files with any redistributed copy and cite the upstream biological sources above. |

The public RNA-seq flow portal summarizes these same sources for readers of the
example reports: <https://taffish.github.io/rnaseq-flows/docs/data-sources.html>.

## Acquisition Plan

The flow is deliberately staged so we can review the plan before pulling data:

1. `plan`: create the output skeleton, selected replicate table, source URL table, methods text, manifest and download plan. This is the default and does not download data.
2. `metadata`: download small metadata files only: ENA run table, author ENA mapping and author excluded-replicate list.
3. `counts`: download the author WT/Snf2 count tarballs, unpack them, map files to the selected biological replicates and build `gene_counts_12v12.tsv`.
4. `reference`: download the SGD S288C `R64.4.1` reference tarball, validate it, extract an uncompressed feature-only gene annotation GFF3, then derive the genome FASTA from the GFF3 embedded FASTA block so sequence IDs match the annotation.
5. `genesets`: build GO-derived GMT files from the SGD annotation and Gene Ontology `go-basic.obo`, plus a background gene list from the selected count matrix.
6. `fastq`: download selected ENA lane FASTQs, verify ENA size/gzip/md5 values, fall back to `submitted_ftp` when the primary `fastq_ftp` object fails validation, merge lanes per biological replicate, then sample reads with SeqKit.
7. `all`: run `metadata`, `counts`, `reference`, `genesets` and `fastq`.

The selected biological replicates are spread across the 1-48 replicate range and avoid the author-listed bad replicates:

- WT: `1, 5, 9, 13, 17, 24, 29, 32, 37, 40, 44, 48`
- SNF2: `1, 5, 9, 14, 18, 22, 26, 30, 34, 38, 42, 46`

Each biological replicate has seven ENA lane/run records. The full FASTQ package therefore downloads 168 lane FASTQs, then writes 24 sampled FASTQ files.

## Recommended Review Run

Default behavior only writes the plan:

```sh
./scripts/run-streaming.sh \
  --outdir yeast-snf2-data-v1
```

After reviewing the output, fetch only the small metadata files:

```sh
./scripts/run-streaming.sh \
  --outdir yeast-snf2-data-v1 \
  --stage metadata \
  --resume true
```

Then do a small network trial before the full FASTQ run:

```sh
./scripts/run-streaming.sh \
  --outdir yeast-snf2-data-v1 \
  --stage fastq \
  --resume true \
  --limit-samples 1
```

Prepare the reference package only:

```sh
./scripts/run-streaming.sh \
  --outdir yeast-snf2-data-v1 \
  --stage reference \
  --resume true
```

Prepare the GO gene-set package only:

```sh
./scripts/run-streaming.sh \
  --outdir yeast-snf2-data-v1 \
  --stage genesets \
  --resume true
```

Full preparation:

```sh
./scripts/run-streaming.sh \
  --outdir yeast-snf2-data-v1 \
  --stage all \
  --resume true
```

For long local data acquisition, prefer `./scripts/run-streaming.sh` in this app directory. It compiles `src/main.taf` to a temporary shell script and runs that shell script directly, so stdout/stderr are streamed immediately. Current `taf run` may buffer child output until the process exits in some local TAFFISH builds, which is uncomfortable for multi-hour downloads.

`--resume true` is the normal way to continue in the same output directory. For example, after `plan`, continue with `metadata`; after `metadata`, continue with `counts` or `fastq`; after a `--limit-samples 1` trial, continue the remaining FASTQ samples in the same directory. Existing final sample FASTQs are reused after gzip checks, and existing lane FASTQs are reused only when size/gzip/md5 checks pass. If an r1 ENA run table is present without `submitted_ftp` fallback columns, r2 automatically refreshes metadata before rebuilding the source accession table.

Use `--force true` only when you intentionally want to redownload or overwrite existing files inside the same `<outdir>`. It does not delete `<outdir>`.

## Output Layout

All generated content is written under `<outdir>/`:

```text
<outdir>/
  00_inputs/
    selected_replicates.tsv
    source_urls.tsv
  01_logs/
    flow.log
    steps/
  02_intermediate/
    metadata/
    cache/
    counts_unpacked/
    merged_fastq/
    tmp/
  03_results/
    yeast-snf2-fastq-mini-v1/
      samples.tsv
      generated_samples.tsv
      metadata.tsv
      source_accessions.tsv
      source_downloads.tsv
      reads/
      expected/
    yeast-snf2-counts-medium-v1/
      source/
      counts/
        gene_counts_12v12.tsv
    yeast-reference-sgd-r64.4.1-v1/
      source/
        S288C_reference_genome_R64-4-1_20230830.tgz
      reference/
        genome/
          yeast_s288c_reference_genome_R64-4-1.fa
          yeast_s288c_reference_genome_R64-4-1.fa.fai
        annotation/
          yeast_s288c_gene_annotation_R64-4-1.gff3
      source_files.tsv
      reference_summary.tsv
      manifest.json
    yeast-sgd-go-gene-sets-r64.4.1-v1/
      source/
        go-basic.obo
      gene_sets/
        sgd_go_bp.gmt
        sgd_go_mf.gmt
        sgd_go_cc.gmt
        sgd_go_all.gmt
      background/
        yeast_background_genes.tsv
      metadata/
        go_terms.tsv
        gene_go_terms.tsv
        gene_set_index.tsv
      source_files.tsv
      gene_sets_summary.tsv
      manifest.json
  04_reports/
    commands.sh
    versions.tsv
    methods.txt
    download-plan.md
    flow_summary.tsv
    checksums.tsv
  run.manifest.json
```

Use `03_results/yeast-snf2-fastq-mini-v1/samples.tsv` for the full 24-sample package. When `--limit-samples` is used for a trial run, use `generated_samples.tsv` because only part of the planned sample set exists.

For formal RNA-seq flow validation, point downstream scripts at the resulting data root, for example:

```sh
export TAFFISH_RNASEQ_TESTDATA=/path/to/taffish-hub/repos/apps/bio/flows/rna-seq/test-data/yeast/data/03_results
```

The expected data root is the `03_results` directory containing packages such
as `yeast-snf2-fastq-mini-v1`, `yeast-snf2-counts-medium-v1`,
`yeast-reference-sgd-r64.4.1-v1`, and `yeast-sgd-go-gene-sets-r64.4.1-v1`.
Formal tests skip cleanly when this tree or a required package is missing.

## Dependencies and Host Tools

Core biological processing is version-pinned through TAFFISH dependencies:

- `taf-seqkit 2.13.0-r2`: FASTQ sampling and FASTQ statistics

Generic host utilities are used for transport and tabular glue: `curl`, `tar`, `gzip`, `awk`, `sort`, `find`, `md5`/`md5sum`, and `sha256sum`/`shasum`. This is intentional for this maintainer data-preparation flow; these are not hidden bioinformatics tools.

## Resource Expectations

`plan` and `metadata` are small. `counts` downloads only a few MB of author count data.

`fastq` is the heavy stage. The full `12+12`, 500k-read package downloads 168 ENA lane FASTQs. Based on earlier single-lane checks, expect roughly 10 GB of lane download traffic before sampling, plus temporary merged FASTQ space inside `<outdir>/02_intermediate/` while each sample is processed. The final sampled FASTQ package is expected to be roughly hundreds of MB to about 1 GB, depending on compression.

`reference` is much smaller than the full FASTQ acquisition. It downloads one SGD archive, checks it as a gzip tarball, extracts a feature-only annotation GFF3, derives the genome FASTA from the GFF3 embedded FASTA block, then records SHA256 values and a reference summary. This matters because the raw SGD FASTA member uses RefSeq-style IDs such as `ref|NC_001133|`, while the SGD GFF3 uses `chrI`, `chrII`, ... `chrmt`; `gffread` requires the FASTA header ID and GFF3 seqid to match exactly. The embedded FASTA block is stripped from the annotation output so annotation-normalization tools do not parse sequence lines as malformed features. The output filenames and directories intentionally include `yeast`, `reference`, `genome`, `gene` and `annotation` terms so `rnaseq-index-flow` formal tests can discover them from the central `03_results` root.

`genesets` is also lightweight. It downloads the Gene Ontology `go-basic.obo`
file when it is not already present, extracts `Ontology_term=GO:...` mappings
from the feature-only SGD GFF3, assigns GO namespaces and names from the OBO
file, writes BP/MF/CC/all GMT files, and creates a background gene list from
`gene_counts_12v12.tsv` after removing non-gene summary rows such as
`ambiguous` and `alignment_not_unique`. The resulting gene IDs are yeast
systematic IDs, matching the DE flow outputs. This package uses GO terms
directly present in SGD GFF3 `Ontology_term` attributes and does not propagate
annotations to GO ancestor terms.

During real acquisition, the main flow prints progress-oriented status messages to stdout and appends them to `<outdir>/01_logs/flow.log`. Each stage reports what it is doing. FASTQ sample processing additionally reports sample index, lane count, ENA run accession, expected size when available, target path and curl progress bar, then size/gzip/md5 verification, primary-source failure messages, fallback-source use, merge, sampling and cleanup status. The FASTQ package writes `source_downloads.tsv` to record the actual source used for each processed lane.

There can be a short silent interval before the first flow log line while TAFFISH prepares dependency wrappers or container commands. Once the main shell flow starts, status messages are emitted immediately.

Recommended local resources for the full run:

- CPU: 2-4 threads
- memory: 4-8 GB
- free disk: at least 30 GB during preparation
- network: stable long-running connection

Use `--limit-samples 1` first to test network behavior and ENA access from the current machine.

If an ENA HTTPS transfer fails with a transient curl/TLS error, rerun with `--resume true`. The flow keeps partial `.tmp` downloads and resumes them with curl `-C -` when possible. Completed lane FASTQs are size/gzip/md5-checked and reused; corrupt cached lane files are removed and downloaded once more. If the primary ENA `fastq_ftp` object itself is invalid or inconsistent with ENA metadata, r2 tries the same run accession's `submitted_ftp` object when ENA provides one, then records `fallback_used=true` in `source_downloads.tsv`.

## Boundaries

This flow is a data acquisition/preparation helper, not an RNA-seq analysis flow. It does not run QC, index building, expression quantification, differential expression, enrichment or reporting.

It prepares a yeast reference genome and annotation package, plus GO-derived gene-set resources for local enrichment formal tests, but it does not build Salmon/Kallisto/STAR/HISAT2 indexes and does not run enrichment statistics itself.

Analysis flows should consume the prepared local outputs and should not download these data at normal runtime.
