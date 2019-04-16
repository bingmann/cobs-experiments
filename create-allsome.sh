#!/bin/bash -x
################################################################################
# Script to construct an AllSome Sequence Bloom Tree from FASTQ and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

export LD_LIBRARY_PATH=${HOME}/dna/lib

BT=${BASEDIR}/bloomtree-allsome/src/bt
BFCLUSTER=${BASEDIR}/bloomtree-allsome/bfcluster/sbuild

NTCARD=${BASEDIR}/bin/ntcard
NCORES=$(grep -c ^processor /proc/cpuinfo)

# create jellyfish hash file
[ -e "allsome-hashfile.hh" ] || $BT hashes allsome-hashfile.hh 1

################################################################################
# use ntcard to estimate bloom filter size

if [ ! -e "allsome_freq_k20.hist" ]; then

    run_exp "experiment=allsome phase=ntcard" \
            $NTCARD --kmer=20 --threads=$NCORES --pref=allsome_freq fastq/*/*.fastq.gz \
        |& tee allsome-ntcard.log

fi

occ=$(awk '$1 ~ /^F0$/ { print $2 }' allsome_freq_k20.hist)
occ1=$(awk '$1 ~ /^F1$/ { print $2 }' allsome_freq_k20.hist)

# README says to use F0 - F1 if cutoff is 1
BF_SIZE=$occ

################################################################################
# construct bloom filters in parallel

mkdir -p allsome

export BT BF_SIZE NCORES
run_exp "experiment=allsome phase=make_bf" bash -c '
(
    for f in fastq/*; do
        OUT="allsome/$(basename "$f").bf.bv"
        UNC="/tmp/$(basename "$f").fasta"
        [ -e "$OUT" ] && continue

        echo -n \
            zcat "$f/*.gz" \| seqtk seq -A \> "$UNC" \&\& \
            $BT count --cutoff 0 --threads 4 allsome-hashfile.hh "${BF_SIZE}" "$UNC" "$OUT" \&\& \
            rm "$UNC"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c |& tee allsome-make_bf.log
'

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

run_exp "experiment=allsome phase=query" \
    $BT query allsome-compressedbloomtreefile allsome-queryfile allsome-outfile \
    |& tee allsome-query.log

################################################################################
