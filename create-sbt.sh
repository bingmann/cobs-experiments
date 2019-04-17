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
NTCARD=${BASEDIR}/bin/ntcard
MCCORTEX=${BASEDIR}/mccortex/bin/mccortex31
COBS=${BASEDIR}/cobs/build/cobs
NCORES=$(grep -c ^processor /proc/cpuinfo)

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
    run_exp "experiment=sbt phase=make_bf" bash -c '
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

    run_exp "experiment=sbt phase=make_bf" bash -c "
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
run_exp "experiment=sbt phase=make_sbt" \
    $BT build sbt-hashfile.hh sbt-listoffiles.txt sbt-bloomtreefile \
    |& tee sbt-make_sbt.log

run_exp "experiment=sbt phase=compress_sbt" \
    $BT compress sbt-bloomtreefile sbt-compressedbloomtreefile \
    |& tee sbt-compress.log

fi
################################################################################
# run queries on SBT

#if [ ! -e "queries.fa" ]; then
    $COBS generate_queries cortex --positive 100000 --negative 100000 \
          -k $K -s $((K + 1)) -N -o queries.fa \
        |& tee sbt-generate_queries.log
    grep -v '^>' queries.fa > queries-plain.fa
#fi

# for SBTs, the threshold is the % of kmers in the query having to match: 50%
# due to expansion with 1 random character
run_exp "experiment=sbt phase=query" \
        $BT query --query-threshold 0.5 \
        sbt-compressedbloomtreefile queries-plain.fa sbt-results.txt \
    >& sbt-query.log

perl $SCRIPT_DIR/check-sbt-results.pl queries.fa sbt-results.txt \
    >& sbt-check_results.log

################################################################################
