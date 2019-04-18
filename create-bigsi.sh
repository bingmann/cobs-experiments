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
NTCARD=${BASEDIR}/bin/ntcard
MCCORTEX=${BASEDIR}/mccortex/bin/mccortex31

# enter virtualenv
source $BIGSI_HOME/bin/activate

NCORES=$(grep -c ^processor /proc/cpuinfo)

################################################################################
# use COBS to estimate bloom filter size

if [ -e fasta ]; then

    K=20
    max_doc=$($HOME/cobs/build/cobs doc_list -k 20 fasta/ | awk '/^maximum 20-mer/ { print $3 }')

elif [ -e cortex ]; then

    K=31
    max_doc=$($HOME/cobs/build/cobs doc_list -k 31 cortex/ | awk '/^maximum 31-mer/ { print $3 }')

fi

prob=0.3
BF_SIZE=$(echo "- $max_doc * l($prob) / (l(2.0) ^ 2)" | bc -l)
BF_SIZE=$(echo $BF_SIZE/1 | bc)

# make YAML config
cat > bigsi-config.yaml <<EOF
## Example config using rocksdb
h: 1
k: $K
m: $BF_SIZE
nproc: 4
storage-engine: rocksdb
storage-config:
  filename: bigsi/bigsi.rocksdb
  options:
    create_if_missing: true
    max_open_files: 5000
  read_only: false ## Change to true for read only access
EOF

if [ ! -e bigsi/bigsi.rocksdb ]; then
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

elif [ -e cortex ]; then

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
) | xargs -0 -n 1 -P $NCORES sh -c' \
    |& tee bigsi-bloom.log

fi

################################################################################
# construct and compress BIGSI index

run_exp "experiment=bigsi phase=build" \
    $BIGSI build --config bigsi-config.yaml bigsi/bloom/* \
    |& tee bigsi-build.log

save_size "experiment=bigsi phase=index" \
          bigsi/bigsi.rocksdb \
    |& tee bigsi-indexsize.log

fi
################################################################################
# run queries on BIGSI

run_exp "experiment=bigsi phase=query" \
    $BIGSI search --config bigsi-config.yaml -t 0.9 \
    AGGTTTGTTTTCTGATATTTGAAAATCGAGA \
    |& tee bigsi-query.log

################################################################################
