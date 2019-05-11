#!/bin/bash -x
################################################################################
# Script to construct a Split Sequence Bloom Tree from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

BT=${BASEDIR}/splitsbt/src/bt

################################################################################
# use ntcard to estimate bloom filter size

if [ -e fasta ]; then
    K=20
    if [ ! -e "ssbt_freq_k$K.hist" ]; then

        run_exp "experiment=ssbt phase=ntcard" \
                $NTCARD --kmer=$K --threads=$NCORES --pref=ssbt_freq fasta/*/*.fasta.gz \
            |& tee ssbt-ntcard.log
    fi
elif [ -e cortex ]; then
    K=31
    if [ ! -e "ssbt_freq_k$K.hist" ]; then

        run_exp "experiment=ssbt phase=ntcard" bash -c "
            (for f in */*/*/*.ctx; do $MCCORTEX view -q -k \$f; done) \
            | awk -f $SCRIPT_DIR/cortex-to-fasta.awk \
            | $NTCARD --kmer=$K --threads=$NCORES --pref=ssbt_freq /dev/stdin" \
            |& tee ssbt-ntcard.log
    fi
fi

occ=$(awk '$1 ~ /^F0$/ { print $2 }' ssbt_freq_k$K.hist)
occ1=$(awk '$1 ~ /^F1$/ { print $2 }' ssbt_freq_k$K.hist)

# README says to use F0 - F1 if cutoff is 1
BF_SIZE=$occ

# create jellyfish hash file
[ -e "ssbt-hashfile.hh" ] || $BT hashes --k $K ssbt-hashfile.hh 1

if [ ! -e ssbt-compressedbloomtreefile ] ; then
################################################################################
# construct bloom filters in parallel

mkdir -p ssbt

if [ -e fasta ]; then

    export BT BF_SIZE NCORES
    run_exp "experiment=ssbt phase=bloom" bash -c '
(
    for f in fasta/*; do
        OUT="ssbt/$(basename "$f").sim.bf.bv"
        #[ -e "$OUT" ] && continue

        echo -n \
            zcat "$f/*.gz" \| \
            $BT count --cutoff 0 --threads 4 ssbt-hashfile.hh ${BF_SIZE} /dev/stdin "$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c' \
    |& tee ssbt-make_bf.log

elif [ -e cortex ]; then

    run_exp "experiment=ssbt phase=bloom" bash -c "
(
    for f in cortex/*; do
        OUT=\"ssbt/\$(basename \$f).sim.bf.bv\"
        #[ -e \"\$OUT\" ] && continue

        echo -n \
            $MCCORTEX view -q -k \$f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fasta.awk \| \
            $BT count --cutoff 0 --threads 4 ssbt-hashfile.hh ${BF_SIZE} /dev/stdin \"\$OUT\"
        echo -ne \"\\0\"
    done
) | xargs -0 -n 1 -P $NCORES sh -c" \
    |& tee ssbt-make_bf.log

fi

################################################################################
# construct and compress SSBT

ls ssbt/*.sim.bf.bv > ssbt-listoffiles.txt
run_exp "experiment=ssbt phase=build" \
    $BT build ssbt-hashfile.hh ssbt-listoffiles.txt ssbt-bloomtreefile \
    |& tee ssbt-make_ssbt.log

run_exp "experiment=ssbt phase=compress" \
    $BT compress ssbt-bloomtreefile ssbt-compressedbloomtreefile \
    |& tee ssbt-compress.log

save_size "experiment=ssbt phase=index" \
          ssbt-compressedbloomtreefile ssbt/*.rrr \
    |& tee ssbt-indexsize.log

fi
################################################################################
# run queries on SSBT

for Q in 1 100 1000 10000; do
    # for SBTs, the threshold is the % of kmers in the query having to match: 50%
    # due to expansion with 1 random character

    run_exp "experiment=ssbt phase=query$Q.0" \
            $BT query --query-threshold 0.9 \
            ssbt-compressedbloomtreefile queries$Q-plain.fa ssbt-results$Q.0.txt \
            >& ssbt-query$Q.0.log

    RESULT="experiment=ssbt dataset=$DATASET phase=check$Q.0" \
    perl $SCRIPT_DIR/check-sbt-results.pl queries$Q.fa ssbt-results$Q.0.txt \
         >& ssbt-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=ssbt phase=query$Q.1" \
            $BT query --query-threshold 0.9 \
            ssbt-compressedbloomtreefile queries$Q-plain.fa ssbt-results$Q.1.txt \
            >& ssbt-query$Q.1.log

    RESULT="experiment=ssbt dataset=$DATASET phase=check$Q.1" \
    perl $SCRIPT_DIR/check-sbt-results.pl queries$Q.fa ssbt-results$Q.1.txt \
         >& ssbt-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=ssbt phase=query$Q.2" \
            $BT query --query-threshold 0.9 \
            ssbt-compressedbloomtreefile queries$Q-plain.fa ssbt-results$Q.2.txt \
            >& ssbt-query$Q.2.log

    RESULT="experiment=ssbt dataset=$DATASET phase=check$Q.2" \
    perl $SCRIPT_DIR/check-sbt-results.pl queries$Q.fa ssbt-results$Q.2.txt \
         >& ssbt-check_results$Q.2.log
done

################################################################################
