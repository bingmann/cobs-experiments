#!/bin/bash -x
################################################################################
# Script to construct an AllSome Sequence Bloom Tree from FASTQ and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

export LD_LIBRARY_PATH=${HOME}/dna/lib

BT=${BASEDIR}/bloomtree-allsome/src/bt
BFCLUSTER=${BASEDIR}/bloomtree-allsome/bfcluster/sbuild

NTCARD=${BASEDIR}/bin/ntcard
MCCORTEX=${BASEDIR}/mccortex/bin/mccortex31
COBS=${BASEDIR}/cobs/build/cobs
NCORES=$(grep -c ^processor /proc/cpuinfo)

################################################################################
# use ntcard to estimate bloom filter size

if [ -e fasta ]; then
    K=20
    if [ ! -e "allsome_freq_k$K.hist" ]; then

        run_exp "experiment=allsome phase=ntcard" \
                $NTCARD --kmer=$K --threads=$NCORES --pref=allsome_freq fastq/*/*.fastq.gz \
            |& tee allsome-ntcard.log
    fi
elif [ -e cortex ]; then
    K=31
    if [ ! -e "allsome_freq_k$K.hist" ]; then

        run_exp "experiment=allsome phase=ntcard" bash -c "
            (for f in cortex/*/*/*.ctx; do $MCCORTEX view -q -k \$f; done) \
            | awk -f $SCRIPT_DIR/cortex-to-fasta.awk \
            | $NTCARD --kmer=$K --threads=$NCORES --pref=allsome_freq /dev/stdin" \
            |& tee allsome-ntcard.log
    fi
fi

occ=$(awk '$1 ~ /^F0$/ { print $2 }' allsome_freq_k$K.hist)
occ1=$(awk '$1 ~ /^F1$/ { print $2 }' allsome_freq_k$K.hist)

# README says to use F0 - F1 if cutoff is 1
BF_SIZE=$occ

# create jellyfish hash file
[ -e "allsome-hashfile.hh" ] || $BT hashes --k $K allsome-hashfile.hh 1

if [ ! -e allsome-compressedbloomtreefile ] ; then
################################################################################
# construct bloom filters in parallel

mkdir -p allsome

if [ -e fasta ]; then

    export BT BF_SIZE NCORES
    run_exp "experiment=allsome phase=make_bf" bash -c '
(
    for f in fastq/*; do
        OUT="allsome/$(basename "$f").bf.bv"
        [ -e "$OUT" ] && continue

        echo -n \
            zcat "$f/*.gz" \| seqtk seq -A \| \
            $BT count --cutoff 0 --threads 4 allsome-hashfile.hh "${BF_SIZE}" /dev/stdin "$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c' \
    |& tee allsome-make_bf.log

elif [ -e cortex ]; then

    export K BT BF_SIZE MCCORTEX NCORES
    run_exp "experiment=allsome phase=make_bf" bash -c "
(
    for f in cortex/*; do
        OUT=\"allsome/\$(basename \$f).bf.bv\"
        #[ -e \"\$OUT\" ] && continue

        echo -n \
            $MCCORTEX view -q -k \$f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fasta.awk \| \
            $BT count --cutoff 0 --threads 4 allsome-hashfile.hh ${BF_SIZE} /dev/stdin \$OUT
        echo -ne \"\\0\"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c" \
    |& tee allsome-make_bf.log

fi

################################################################################
# construct and compress ALLSOME

ls allsome/*.bf.bv > allsome-listoffiles.txt
run_exp "experiment=allsome phase=make_sbt" \
    $BT build allsome-hashfile.hh allsome-listoffiles.txt allsome-bloomtreefile \
    |& tee allsome-make_allsome.log

# TODO: parallel compress!
run_exp "experiment=allsome phase=compress_sbt" \
    $BT compress allsome-bloomtreefile allsome-compressedbloomtreefile \
    |& tee allsome-compress.log

fi
################################################################################

#if [ ! -e queries.fa ]; then
    $COBS generate_queries cortex --positive 100000 --negative 100000 \
          -k $K -s $((K + 1)) -N -o queries.fa \
        |& tee allsome-generate_queries.log
#fi

# for SBTs, the threshold is the % of kmers in the query having to match: 50%
# due to expansion with 1 random character
run_exp "experiment=allsome phase=query" \
        $BT query --query-threshold 0.5 \
        allsome-compressedbloomtreefile queries.fa allsome-results.txt \
    |& tee allsome-query.log

perl $SCRIPT_DIR/check-allsome-results.pl queries.fa allsome-results.txt \
    >& allsome-check_results.log

################################################################################
