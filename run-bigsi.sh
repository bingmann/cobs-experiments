#!/bin/bash -x
################################################################################
# Script to construct a BIGSI Index from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

BASEDIR=${HOME}/dna/
BIGSI_HOME=${BASEDIR}/bigsi
BIGSI=${BASEDIR}/bigsi/bin/bigsi

# enter virtualenv
source $BIGSI_HOME/bin/activate

ulimit -n 1000000

################################################################################
# use COBS to estimate bloom filter size

if [ -e fasta ]; then

    K=20
    max_doc=$($COBS doc-list -k 20 fasta/ |& awk '/^maximum 20-mer/ { print $3 }')

elif [ -e cortex ]; then

    K=31
    max_doc=$($COBS doc-list -k 31 cortex/ |& awk '/^maximum 31-mer/ { print $3 }')

fi

prob=0.3
BF_SIZE=$(echo "- $max_doc * l($prob) / (l(2.0) ^ 2)" | bc -l)
BF_SIZE=$(echo $BF_SIZE/1 | bc)

# make YAML config
cat > bigsi-config.yaml <<EOF
## Example config using rocksdb
h: 1
k: $K
m: ${BF_SIZE}
nproc: $NCORES
low_mem_build: false
storage-engine: rocksdb
storage-config:
  filename: bigsi/bigsi.db
  options:
    create_if_missing: true
    max_open_files: 5000
    # compression: lz4
  read_only: false
EOF

# make YAML config
cat > bigsi-config.yaml <<EOF
## Example config using berkeleydb
h: 1
k: $K
m: ${BF_SIZE}
nproc: $NCORES
low_mem_build: false
max_build_mem_bytes: 100GB
storage-engine: berkeleydb
storage-config:
  filename: bigsi/bigsi.db
EOF

if [ ! -e bigsi/bigsi.db ]; then
################################################################################
# construct bloom filters in parallel

mkdir -p bigsi/cortex

if [ -e fasta ]; then

    # convert fasta to cortex (separate time measurement)
    export K MCCORTEX NCORES
    run_exp "experiment=bigsi phase=make_ctx" bash -c '
(
    for f in fasta/*; do
        CTX="bigsi/cortex/$(basename "$f").ctx"
        [ -e "$CTX" ] && continue

        echo -n \
             zcat "$f/*.gz" \| \
             $MCCORTEX build --kmer $K --threads 8 --mem 32G \
                 --sample $(basename "$f") --seq /dev/stdin --force "$CTX"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $((NCORES / 8)) sh -c' \
    |& tee bigsi-make_ctx.log

    # construct bloom filters
    mkdir -p bigsi/bloom

    export BIGSI NCORES
    run_exp "experiment=bigsi phase=bloom" bash -c '
(
    for f in fasta/*; do
        CTX="bigsi/cortex/$(basename "$f").ctx"
        OUT="bigsi/bloom/$(basename "$f").bloom"
        #[ -e "$OUT" ] && continue

        echo -n \
             $BIGSI bloom --config bigsi-config.yaml "$CTX" "$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $NCORES sh -c' \
    |& tee bigsi-bloom.log

elif [ -e cortex -a ! -e bigsi/bloom.done ]; then

    # construct bloom filters directly from cortex
    mkdir -p bigsi/bloom

    export BIGSI NCORES
    run_exp "experiment=bigsi phase=bloom" bash -c '
(
    for f in cortex/*; do
        CTX="$f/*/*.ctx"
        OUT="bigsi/bloom/$(basename "$f").bloom"
        #[ -e "$OUT" ] && continue

        echo -n \
             $BIGSI bloom --config bigsi-config.yaml $CTX "$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -r -n 1 -P $NCORES sh -c' \
    |& tee bigsi-bloom.log

    touch bigsi/bloom.done

fi

################################################################################
# construct and compress BIGSI index

(for f in bigsi/bloom/*; do
     echo -e "$f\t$(basename $f)"
 done) > bigsi-bloom.txt

run_exp "experiment=bigsi phase=build" \
    $BIGSI build --config bigsi-config.yaml --from_file bigsi-bloom.txt \
    |& tee bigsi-build.log

save_size "experiment=bigsi phase=index" \
          bigsi/bigsi.db \
    |& tee bigsi-indexsize.log

fi
################################################################################
# run queries on BIGSI

for Q in 1 100 1000 10000; do
    run_exp "experiment=bigsi phase=query$Q.0" \
            $BIGSI bulk_search --config bigsi-config.yaml -t 0.9 --stream --format csv \
            queries$Q.fa \
        >& bigsi-results$Q.0.out


    grep -v '^"' bigsi-results$Q.0.out > bigsi-results$Q.0.log

    RESULT="experiment=bigsi dataset=$DATASET phase=check$Q.0" \
    perl $SCRIPT_DIR/check-bigsi-results.pl queries$Q.fa bigsi-results$Q.0.out \
         >& bigsi-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=bigsi phase=query$Q.1" \
            $BIGSI bulk_search --config bigsi-config.yaml -t 0.9 --stream --format csv \
            queries$Q.fa \
        >& bigsi-results$Q.1.out

    grep -v '^"' bigsi-results$Q.1.out > bigsi-results$Q.1.log

    RESULT="experiment=bigsi dataset=$DATASET phase=check$Q.1" \
    perl $SCRIPT_DIR/check-bigsi-results.pl queries$Q.fa bigsi-results$Q.1.out \
         >& bigsi-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=bigsi phase=query$Q.2" \
            $BIGSI bulk_search --config bigsi-config.yaml -t 0.9 --stream --format csv \
            queries$Q.fa \
        >& bigsi-results$Q.2.out

    grep -v '^"' bigsi-results$Q.2.out > bigsi-results$Q.2.log

    RESULT="experiment=bigsi dataset=$DATASET phase=check$Q.2" \
    perl $SCRIPT_DIR/check-bigsi-results.pl queries$Q.fa bigsi-results$Q.2.out \
         >& bigsi-check_results$Q.2.log
done

################################################################################
