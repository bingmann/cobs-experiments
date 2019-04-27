#!/bin/bash -x
################################################################################
# Script to construct a COBS Index and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

BASEDIR=${HOME}/dna/

ulimit -n 1000000

################################################################################
# use COBS to estimate bloom filter size

if [ -e fasta ]; then
    K=20
elif [ -e cortex ]; then
    K=31
fi

if [ ! -e cobs-classic ]; then
################################################################################
# construct compressed COBS index

run_exp "experiment=cobs_classic phase=build" \
    $COBS classic-construct --term-size $K --clobber cortex cobs-classic \
    --false-positive-rate 0.3 --canonicalize \
    |& tee cobs_classic-build.log

save_size "experiment=cobs_classic phase=index" \
    cobs-classic \
    |& tee cobs_classic-indexsize.log

fi

if [ ! -e cobs-compact ]; then
################################################################################
# construct compressed COBS index

run_exp "experiment=cobs_compact phase=build" \
    $COBS compact-construct --term-size $K --clobber cortex cobs-compact \
    --false-positive-rate 0.3 --canonicalize \
    |& tee cobs_comapct-build.log

save_size "experiment=cobs_compact phase=index" \
    cobs-compact \
    |& tee cobs_compact-indexsize.log

fi
################################################################################
# run queries on COBS

for Q in 1 100 1000 10000; do
    run_exp "experiment=cobs_classic phase=query$Q" \
            $COBS query --threshold 0.9 -i cobs-classic/index.cobs_classic \
            --load-complete -f queries$Q.fa \
            >& cobs_classic-results$Q.log

    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_classic-results$Q.log \
         >& cobs_classic-check_results$Q.log


    run_exp "experiment=cobs_compact phase=query$Q" \
            $COBS query --threshold 0.9 -i cobs-compact/index.cobs_compact \
            --load-complete -f queries$Q.fa \
            >& cobs_compact-results$Q.log

    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_compact-results$Q.log \
         >& cobs_compact-check_results$Q.log
done

################################################################################
