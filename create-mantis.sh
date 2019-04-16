#!/bin/bash -x
################################################################################
# Script to construct a Mantis Index from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

SEQTK=${BASEDIR}/bin/seqtk
SQUEAKR=${BASEDIR}/squeakr/squeakr
MANTIS=${BASEDIR}/mantis/build/src/mantis
MCCORTEX=${BASEDIR}/mccortex/bin/mccortex31

NCORES=$(grep -c ^processor /proc/cpuinfo)

DATADIR=$PWD

################################################################################
# construct squeaker counts in parallel

mkdir -p mantis/squeakr

if [ -e fasta ]; then

    export SEQTK SQUEAKR NCORES
    run_exp "experiment=mantis phase=squeakr" bash -c '
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
    run_exp "experiment=mantis phase=squeakr" bash -c '
(
    for f in cortex/*; do
        OUT="$PWD/mantis/squeakr/$(basename "$f").squeakr"
        FIFO="/tmp/$(basename "$f").fastq"
        #[ -e "$OUT" ] && continue
        rm -f "$FIFO"

        echo -n \
            mkfifo "$FIFO" \&\& \
            $MCCORTEX view -q -k $f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO" \& \
            $SQUEAKR count --exact -k 31 -c 1 -t 1 -o "$OUT.tmp" "$FIFO" \&\& \
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

ulimit -n 1000000
run_exp "experiment=mantis phase=mantis" \
    $MANTIS build -s 31 -i mantis-input.txt -o mantis/ \
    |& tee ../mantis-mantis.log

run_exp "experiment=mantis phase=build_mst" \
    $MANTIS mst -p $PWD/mantis/ -t $NCORES --delete-RRR \
    |& tee ../mantis-build_mst.log

run_exp "experiment=mantis phase=query" \
    $MANTIS query -k 31 -p $PWD/mantis/ -o $DATADIR/mantis-output.txt $DATADIR/queries.fa \
    |& tee ../mantis-query.log

################################################################################
