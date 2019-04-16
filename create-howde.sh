#!/bin/bash -x
################################################################################
# Script to construct an HowDe Sequence Bloom Tree from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

export LD_LIBRARY_PATH=${HOME}/dna/lib

BT=${BASEDIR}/HowDeSBT/howdesbt
NTCARD=${BASEDIR}/bin/ntcard
MCCORTEX=${BASEDIR}/mccortex/bin/mccortex31
NCORES=$(grep -c ^processor /proc/cpuinfo)

################################################################################
# use ntcard to estimate bloom filter size

if [ ! -e "howde_freq_k20.hist" ]; then
    if [ -e fasta ]; then

        run_exp "experiment=howde phase=ntcard" \
                $NTCARD --kmer=20 --threads=$NCORES --pref=howde_freq fasta/*/*.fasta.gz \
            |& tee howde-ntcard.log

    elif [ -e cortex ]; then

        run_exp "experiment=howde phase=ntcard" bash -c "
            (for f in cortex/*/*/*.ctx; do $MCCORTEX view -q -k \$f; done) \
            | awk -f $SCRIPT_DIR/cortex-to-fasta.awk \
            | $NTCARD --kmer=20 --threads=$NCORES --pref=howde_freq /dev/stdin" \
            |& tee howde-ntcard.log
    fi
fi

occ=$(awk '$1 ~ /^F0$/ { print $2 }' howde_freq_k20.hist)
occ1=$(awk '$1 ~ /^F1$/ { print $2 }' howde_freq_k20.hist)

# README says to use F0 - F1 if cutoff is 1
BF_SIZE=$occ

################################################################################
# construct bloom filters in parallel

mkdir -p howde/bf

if [ -e fasta ]; then

    export BT BF_SIZE NCORES
    run_exp "experiment=howde phase=make_bf" bash -c '
(
    for f in fasta/*; do
        OUT="howde/bf/$(basename "$f").bf"
        #[ -e "$OUT" ] && continue

        echo -n \
            zcat "$f/*.gz" \| \
            $BT makebf --k=20 --min=0 --bits=${BF_SIZE} --threads=4 "/dev/stdin" --out="$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c' \
    |& tee howde-make_bf.log

elif [ -e cortex ]; then

    export BT BF_SIZE MCCORTEX NCORES
    run_exp "experiment=howde phase=make_bf" bash -c "
(
    for f in cortex/*; do
        OUT=\"howde/bf/\$(basename \$f).bf\"
        #[ -e \"\$OUT\" ] && continue

        echo -n \
            $MCCORTEX view -q -k \$f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fasta.awk \| \
            $BT makebf --k=20 --min=0 --bits=${BF_SIZE} --threads=4 /dev/stdin --out=\$OUT
        echo -ne \"\\0\"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c" \
    |& tee howde-make_bf.log

fi

################################################################################
# construct and compress HOWDE

cd howde
ls bf/*.bf > howde-leafnames.txt
run_exp "experiment=howde phase=cluster" \
    $BT cluster --list=howde-leafnames.txt --bits=$((BF_SIZE / 10)) \
    --tree=howde-union.sbt --nodename=node{number} --keepallnodes \
    |& tee ../howde-make_howde.log

# TODO: parallel compress!

run_exp "experiment=howde phase=compress" \
    $BT build --HowDe --tree=howde-union.sbt --outtree=howde-howde.sbt \
    |& tee ../howde-compress.log

#$BT query --tree=howde.sbt ../queryfile > outfile

# run_exp "experiment=howde phase=query" \
#     $BT query howde-compressedbloomtreefile howde-queryfile howde-outfile \
#     |& tee howde-query.log

################################################################################
