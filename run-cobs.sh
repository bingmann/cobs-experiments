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

if [ ! -e cobs-index.cobs_classic ]; then
################################################################################
# construct compressed COBS index

run_exp "experiment=cobs_classic phase=build" \
    $COBS classic-construct --term-size $K --clobber cortex cobs-index.cobs_classic \
    --false-positive-rate 0.3 --canonicalize \
    |& tee cobs_classic-build.log

save_size "experiment=cobs_classic phase=index" \
    cobs-index.cobs_classic \
    |& tee cobs_classic-indexsize.log

fi

if [ ! -e cobs-index.cobs_compact ]; then
################################################################################
# construct compressed COBS index

run_exp "experiment=cobs_compact phase=build" \
    $COBS compact-construct --term-size $K --clobber cortex cobs-index.cobs_compact \
    --false-positive-rate 0.3 --canonicalize \
    |& tee cobs_comapct-build.log

save_size "experiment=cobs_compact phase=index" \
    cobs-index.cobs_compact \
    |& tee cobs_compact-indexsize.log

fi
################################################################################
# run queries on COBS

for Q in 1 100 1000 10000; do
    ################################################################################
    # Classic Index
    run_exp "experiment=cobs_classic phase=query$Q.0" \
            $COBS query --threshold 0.9 -i cobs-index.cobs_classic \
            --load-complete -f queries$Q.fa \
            > cobs_classic-results$Q.0.out \
            2> cobs_classic-results$Q.log

    RESULT="experiment=cobs_classic phase=check$Q.0" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_classic-results$Q.0.out \
         >& cobs_classic-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=cobs_classic phase=query$Q.1" \
            $COBS query --threshold 0.9 -i cobs-index.cobs_classic \
            --load-complete -f queries$Q.fa \
            > cobs_classic-results$Q.1.out \
            2> cobs_classic-results$Q.1.log

    RESULT="experiment=cobs_classic phase=check$Q.1" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_classic-results$Q.1.out \
         >& cobs_classic-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=cobs_classic phase=query$Q.2" \
            $COBS query --threshold 0.9 -i cobs-index.cobs_classic \
            --load-complete -f queries$Q.fa \
            > cobs_classic-results$Q.2.out \
            2> cobs_classic-results$Q.2.log

    RESULT="experiment=cobs_classic phase=check$Q.2" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_classic-results$Q.2.out \
         >& cobs_classic-check_results$Q.2.log

    ################################################################################
    # Compact Index
    run_exp "experiment=cobs_compact phase=query$Q.0" \
            $COBS query --threshold 0.9 -i cobs-index.cobs_compact \
            --load-complete -f queries$Q.fa \
            > cobs_compact-results$Q.0.out \
            2> cobs_compact-results$Q.0.log

    RESULT="experiment=cobs_compact phase=check$Q.0" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_compact-results$Q.0.out \
         >& cobs_compact-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=cobs_compact phase=query$Q.1" \
            $COBS query --threshold 0.9 -i cobs-index.cobs_compact \
            --load-complete -f queries$Q.fa \
            > cobs_compact-results$Q.1.out \
            2> cobs_compact-results$Q.1.log

    RESULT="experiment=cobs_compact phase=check$Q.1" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_compact-results$Q.1.out \
         >& cobs_compact-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=cobs_compact phase=query$Q.2" \
            $COBS query --threshold 0.9 -i cobs-index.cobs_compact \
            --load-complete -f queries$Q.fa \
            > cobs_compact-results$Q.2.out \
            2> cobs_compact-results$Q.2.log

    RESULT="experiment=cobs_compact phase=check$Q.2" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl cobs_compact-results$Q.2.out \
         >& cobs_compact-check_results$Q.2.log
done

################################################################################
