#!/bin/bash -x
################################################################################
# Script to construct an HowDe Sequence Bloom Tree from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

export LD_LIBRARY_PATH=${HOME}/dna/lib

BT=${BASEDIR}/HowDeSBT/howdesbt

DATADIR=$PWD

################################################################################
# use ntcard to estimate bloom filter size

if [ -e fasta ]; then
    K=20
    if [ ! -e "howde_freq_k$K.hist" ]; then

        run_exp "experiment=howde phase=ntcard" \
                $NTCARD --kmer=$K --threads=$NCORES --pref=howde_freq fasta/*/*.fasta.gz \
            |& tee howde-ntcard.log
    fi
elif [ -e cortex ]; then
    K=31
    if [ ! -e "howde_freq_k$K.hist" ]; then

        run_exp "experiment=howde phase=ntcard" bash -c "
            (for f in cortex/*/*/*.ctx; do $MCCORTEX view -q -k \$f; done) \
            | awk -f $SCRIPT_DIR/cortex-to-fasta.awk \
            | $NTCARD --kmer=$K --threads=$NCORES --pref=howde_freq /dev/stdin" \
            |& tee howde-ntcard.log
    fi
fi

occ=$(awk '$1 ~ /^F0$/ { print $2 }' howde_freq_k$K.hist)
occ1=$(awk '$1 ~ /^F1$/ { print $2 }' howde_freq_k$K.hist)

# README says to use F0 - F1 if cutoff is 1
BF_SIZE=$occ

if [ ! -e howde/howde-howde.sbt ]; then
################################################################################
# construct bloom filters in parallel

mkdir -p howde/bf

if [ -e fasta ]; then

    export K BT BF_SIZE NCORES
    run_exp "experiment=howde phase=bloom" bash -c '
(
    for f in fasta/*; do
        OUT="howde/bf/$(basename "$f").bf"
        #[ -e "$OUT" ] && continue

        echo -n \
            zcat "$f/*.gz" \| \
            $BT makebf --k=$K --min=0 --bits=${BF_SIZE} --threads=4 "/dev/stdin" --out="$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c' \
    |& tee howde-make_bf.log

elif [ -e cortex ]; then

    export K BT BF_SIZE MCCORTEX NCORES
    run_exp "experiment=howde phase=bloom" bash -c "
(
    for f in cortex/*; do
        OUT=\"howde/bf/\$(basename \$f).bf\"
        #[ -e \"\$OUT\" ] && continue

        echo -n \
            $MCCORTEX view -q -k \$f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fasta.awk \| \
            $BT makebf --k=$K --min=0 --bits=${BF_SIZE} --threads=4 /dev/stdin --out=\$OUT
        echo -ne \"\\0\"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c" \
    |& tee howde-make_bf.log

fi

################################################################################
# construct and compress HOWDE

cd howde

ls bf/*.bf > howde-leafnames.txt
run_exp "experiment=howde phase=build" \
        $BT cluster --list=howde-leafnames.txt --bits=$((BF_SIZE)) \
        --tree=howde-union.sbt --nodename=node{number} --keepallnodes \
    |& tee ../howde-make_howde.log

# TODO: parallel compress!
run_exp "experiment=howde phase=compress" \
        $BT build --HowDe --tree=howde-union.sbt --outtree=howde-howde.sbt \
    |& tee ../howde-compress.log

save_size "experiment=howde phase=index" \
          howde-howde.sbt *.rrr.bf \
    |& tee ../howde-indexsize.log

fi
################################################################################
# run queries on SBT

cd $DATADIR

for Q in 1 100 1000 10000; do

    run_exp "experiment=howde phase=query$Q.0" \
            $BT query --tree=howde/howde-howde.sbt --threshold=0.9 queries$Q.fa \
            --out=howde-results$Q.0.txt \
            >& howde-query$Q.0.log

    RESULT="experiment=howde dataset=$DATASET phase=check$Q.0" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl howde-results$Q.0.txt \
         >& howde-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=howde phase=query$Q.1" \
            $BT query --tree=howde/howde-howde.sbt --threshold=0.9 queries$Q.fa \
            --out=howde-results$Q.1.txt \
            >& howde-query$Q.1.log

    RESULT="experiment=howde dataset=$DATASET phase=check$Q.1" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl howde-results$Q.1.txt \
         >& howde-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=howde phase=query$Q.2" \
            $BT query --tree=howde/howde-howde.sbt --threshold=0.9 queries$Q.fa \
            --out=howde-results$Q.2.txt \
            >& howde-query$Q.2.log

    RESULT="experiment=howde dataset=$DATASET phase=check$Q.2" \
    perl $SCRIPT_DIR/check-howde-cobs-results.pl howde-results$Q.2.txt \
         >& howde-check_results$Q.2.log
done

################################################################################
