#!/bin/bash -x
################################################################################
# Script to construct a Sequence Bloom Tree from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

BT=${BASEDIR}/bloomtree/src/bt

################################################################################
# use ntcard to estimate bloom filter size

if [ -e fasta ]; then
    K=20
    if [ ! -e "sbt_freq_k$K.hist" ]; then

        run_exp "experiment=sbt phase=ntcard" \
                $NTCARD --kmer=$K --threads=$NCORES --pref=sbt_freq fasta/*/*.fasta.gz \
            |& tee sbt-ntcard.log
    fi
elif [ -e cortex ]; then
    K=31
    if [ ! -e "sbt_freq_k$K.hist" ]; then

        run_exp "experiment=sbt phase=ntcard" bash -c "
            (for f in cortex/*/*/*.ctx; do $MCCORTEX view -q -k \$f; done) \
            | awk -f $SCRIPT_DIR/cortex-to-fasta.awk \
            | $NTCARD --kmer=$K --threads=$NCORES --pref=sbt_freq /dev/stdin" \
            |& tee sbt-ntcard.log
    fi
fi

occ=$(awk '$1 ~ /^F0$/ { print $2 }' sbt_freq_k$K.hist)
occ1=$(awk '$1 ~ /^F1$/ { print $2 }' sbt_freq_k$K.hist)

# README says to use F0 - F1 if cutoff is 1
BF_SIZE=$occ

# create jellyfish hash file
[ -e "sbt-hashfile.hh" ] || $BT hashes --k $K sbt-hashfile.hh 1

if [ ! -e sbt-compressedbloomtreefile ]; then
################################################################################
# construct bloom filters in parallel

mkdir -p sbt

if [ -e fasta ]; then

    export BT BF_SIZE NCORES
    run_exp "experiment=sbt phase=bloom" bash -c '
(
    for f in fasta/*; do
        OUT="sbt/$(basename "$f").bf.bv"
        #[ -e "$OUT" ] && continue

        echo -n \
            zcat "$f/*.gz" \| \
            $BT count --cutoff 0 sbt-hashfile.hh ${BF_SIZE} /dev/stdin "$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $NCORES sh -c' \
    |& tee sbt-make_bf.log

elif [ -e cortex ]; then

    run_exp "experiment=sbt phase=bloom" bash -c "
(
    for f in cortex/*; do
        OUT=\"sbt/\$(basename \$f).bf.bv\"
        #[ -e \"\$OUT\" ] && continue

        echo -n \
            $MCCORTEX view -q -k \$f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fasta.awk \| \
            $BT count --cutoff 0 sbt-hashfile.hh ${BF_SIZE} /dev/stdin \"\$OUT\"
        echo -ne \"\\0\"
    done
) | xargs -0 -n 1 -P $NCORES sh -c" \
    |& tee sbt-make_bf.log

fi

################################################################################
# construct and compress SBT

ls sbt/*.bf.bv > sbt-listoffiles.txt
run_exp "experiment=sbt phase=build" \
    $BT build sbt-hashfile.hh sbt-listoffiles.txt sbt-bloomtreefile \
    |& tee sbt-make_sbt.log

run_exp "experiment=sbt phase=compress" \
    $BT compress sbt-bloomtreefile sbt-compressedbloomtreefile \
    |& tee sbt-compress.log

save_size "experiment=sbt phase=index" \
          sbt-compressedbloomtreefile sbt/*.rrr \
    |& tee sbt-indexsize.log

fi
################################################################################
# run queries on SBT

for Q in 1 100 1000 10000; do
    # for SBTs, the threshold is the % of kmers in the query having to match: 50%
    # due to expansion with 1 random character

    run_exp "experiment=sbt phase=query$Q.0" \
            $BT query --query-threshold 0.5 \
            sbt-compressedbloomtreefile queries$Q-plain.fa sbt-results$Q.0.txt \
            >& sbt-query$Q.0.log

    RESULT="experiment=sbt phase=check$Q.0" \
    perl $SCRIPT_DIR/check-sbt-results.pl queries$Q.fa sbt-results$Q.0.txt \
         >& sbt-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=sbt phase=query$Q.1" \
            $BT query --query-threshold 0.5 \
            sbt-compressedbloomtreefile queries$Q-plain.fa sbt-results$Q.1.txt \
            >& sbt-query$Q.1.log

    RESULT="experiment=sbt phase=check$Q.1" \
    perl $SCRIPT_DIR/check-sbt-results.pl queries$Q.fa sbt-results$Q.1.txt \
         >& sbt-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=sbt phase=query$Q.2" \
            $BT query --query-threshold 0.5 \
            sbt-compressedbloomtreefile queries$Q-plain.fa sbt-results$Q.2.txt \
            >& sbt-query$Q.2.log

    RESULT="experiment=sbt phase=check$Q.2" \
    perl $SCRIPT_DIR/check-sbt-results.pl queries$Q.fa sbt-results$Q.2.txt \
         >& sbt-check_results$Q.2.log
done

################################################################################
