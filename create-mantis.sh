#!/bin/bash -x
################################################################################
# Script to construct a Mantis Index from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

SEQTK=${BASEDIR}/bin/seqtk
SQUEAKR=${BASEDIR}/squeakr/squeakr
MANTIS=${BASEDIR}/mantis/build/src/mantis
DATADIR=$PWD

ulimit -n 1000000

if [ ! -e mantis/mantis/dbg_cqf.ser ]; then
################################################################################
# construct squeaker counts in parallel

mkdir -p mantis/squeakr

if [ -e fasta ]; then

    export SEQTK SQUEAKR NCORES
    run_exp "experiment=mantis phase=bloom" bash -c '
(
    for f in fasta/*; do
        OUT="$PWD/mantis/squeakr/$(basename "$f").squeakr"
        FIFO="/tmp/$(basename "$f").fastq"
        #[ -e "$OUT" ] && continue
        rm -f "$FIFO"

        echo -n \
            mkfifo "$FIFO" \&\& \
            zcat $f/*.gz \| $SEQTK seq -F X \> "$FIFO" \& \
            $SQUEAKR count --exact -k 31 -c 1 -t 1 -o "$OUT.tmp" "$FIFO" \&\& \
            mv "$OUT.tmp" "$OUT" \&\& \
            rm "$FIFO"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $NCORES bash -c' \
    |& tee mantis-squeakr.log

elif [ -e cortex ]; then

    export MCCORTEX SCRIPT_DIR SQUEAKR NCORES
    run_exp "experiment=mantis phase=bloom" bash -c '
(
    for f in cortex/*; do
        OUT="$PWD/mantis/squeakr/$(basename "$f").squeakr"
        FIFO="/tmp/$(basename "$f").fastq"
        #[ -e "$OUT" ] && continue
        rm -f "$FIFO"

        echo -n \
            mkfifo "$FIFO" \&\& \
            \($MCCORTEX view -q -k $f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO" \& \
            $SQUEAKR count --exact -k 31 -c 1 -t 1 -o "$OUT.tmp" "$FIFO"\) \&\& \
            mv "$OUT.tmp" "$OUT" \&\& \
            rm "$FIFO"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $NCORES bash -c' \
    |& tee mantis-squeakr.log

fi

################################################################################
# construct and compress MANTIS

cd mantis
ls squeakr/*.squeakr > mantis-input.txt

run_exp "experiment=mantis phase=build" \
    $MANTIS build -s 31 -i mantis-input.txt -o mantis/ \
    |& tee ../mantis-mantis.log

run_exp "experiment=mantis phase=compress" \
    $MANTIS mst -p $PWD/mantis/ -t $NCORES --delete-RRR \
    |& tee ../mantis-build_mst.log

save_size "experiment=mantis phase=index" \
          mantis/* \
    |& tee ../mantis-indexsize.log

fi
################################################################################
# run queries on MANTIS

cd $DATADIR
K=31

for Q in 1 100 1000 10000; do
    run_exp "experiment=mantis phase=query$Q" \
            $MANTIS query -k $K -p $PWD/mantis/mantis/ -o mantis-results$Q.txt \
            $PWD/queries$Q-plain.fa \
        |& tee mantis-query$Q.log

    perl $SCRIPT_DIR/check-mantis-results.pl queries$Q.fa mantis-results$Q.txt \
        |& tee mantis-check_results$Q.log
done

################################################################################
