#!/bin/bash -x
################################################################################
# Script to run Jellyfish on batches of 10 cortex files.
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

################################################################################
# construct squeaker counts in parallel

mkdir -p jellyfish

if [ -e cortex ]; then

    export MCCORTEX SCRIPT_DIR SQUEAKR NCORES
    run_exp "experiment=jellyfish phase=count" bash -c '
(
    arr=(cortex/*);

    for ((i=0; i <${#arr[@]}; i+=10)); do
        OUT="$PWD/jellyfish/$i.jf"
        FIFO0="/tmp/$(basename "${arr[$i+0]}").fastq"
        FIFO1="/tmp/$(basename "${arr[$i+1]}").fastq"
        FIFO2="/tmp/$(basename "${arr[$i+2]}").fastq"
        FIFO3="/tmp/$(basename "${arr[$i+3]}").fastq"
        FIFO4="/tmp/$(basename "${arr[$i+4]}").fastq"
        FIFO5="/tmp/$(basename "${arr[$i+5]}").fastq"
        FIFO6="/tmp/$(basename "${arr[$i+6]}").fastq"
        FIFO7="/tmp/$(basename "${arr[$i+7]}").fastq"
        FIFO8="/tmp/$(basename "${arr[$i+8]}").fastq"
        FIFO9="/tmp/$(basename "${arr[$i+9]}").fastq"
        #[ -e "$OUT" ] && continue
        rm -f "$FIFO0"
        rm -f "$FIFO1"
        rm -f "$FIFO2"
        rm -f "$FIFO3"
        rm -f "$FIFO4"
        rm -f "$FIFO5"
        rm -f "$FIFO6"
        rm -f "$FIFO7"
        rm -f "$FIFO8"
        rm -f "$FIFO9"

        echo -n \
            mkfifo "$FIFO0" \&\& \
            mkfifo "$FIFO1" \&\& \
            mkfifo "$FIFO2" \&\& \
            mkfifo "$FIFO3" \&\& \
            mkfifo "$FIFO4" \&\& \
            mkfifo "$FIFO5" \&\& \
            mkfifo "$FIFO6" \&\& \
            mkfifo "$FIFO7" \&\& \
            mkfifo "$FIFO8" \&\& \
            mkfifo "$FIFO9" \&\& \
            \($MCCORTEX view -q -k ${arr[$i+0]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO0" \& \
            $MCCORTEX view -q -k ${arr[$i+1]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO1" \& \
            $MCCORTEX view -q -k ${arr[$i+2]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO2" \& \
            $MCCORTEX view -q -k ${arr[$i+3]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO3" \& \
            $MCCORTEX view -q -k ${arr[$i+4]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO4" \& \
            $MCCORTEX view -q -k ${arr[$i+5]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO5" \& \
            $MCCORTEX view -q -k ${arr[$i+6]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO6" \& \
            $MCCORTEX view -q -k ${arr[$i+7]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO7" \& \
            $MCCORTEX view -q -k ${arr[$i+8]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO8" \& \
            $MCCORTEX view -q -k ${arr[$i+9]}/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \> "$FIFO9" \& \
            ~/dna/bin/jellyfish count -s 512M -m 31 -C -t 1 -o "$OUT.tmp" "$FIFO0" "$FIFO1" "$FIFO2" "$FIFO3" "$FIFO4" "$FIFO5" "$FIFO6" "$FIFO7" "$FIFO8" "$FIFO9"\) \&\& \
            mv "$OUT.tmp" "$OUT" \&\& \
            rm "$FIFO0" "$FIFO1" "$FIFO2" "$FIFO3" "$FIFO4" "$FIFO5" "$FIFO6" "$FIFO7" "$FIFO8" "$FIFO9"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $NCORES bash -c' \
    |& tee count-jellyfish.log

fi

################################################################################
