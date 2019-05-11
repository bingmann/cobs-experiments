#!/bin/bash -x
################################################################################
# Script to construct a SeqOthello Index from FASTA and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

SEQTK=${BASEDIR}/bin/seqtk
JELLYFISH=${BASEDIR}/bin/jellyfish
SEQOTHELLO=${BASEDIR}/SeqOthello/build/bin/
DATADIR=$PWD

if [ ! -e seqothello/map/map.xml ]; then
################################################################################
# STEP1: Jellyfish counts

mkdir -p seqothello/jellyfish/

if [ -e fasta ]; then

    echo "FIXME"
    exit

    export SEQTK JELLYFISH SEQOTHELLO NCORES
    run_exp "experiment=seqothello phase=count" bash -c '
(
    for f in fasta/*; do
        OUT="$PWD/seqothello/squeakr/$(basename "$f").squeakr"
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
    |& tee seqothello-jellyfish.log

elif [ -e cortex ]; then

    export MCCORTEX JELLYFISH SEQOTHELLO NCORES SCRIPT_DIR
    run_exp "experiment=seqothello phase=count" bash -c '
(
    for f in cortex/*; do
        JOUT="$PWD/seqothello/jellyfish/$(basename "$f").jf"
        KOUT="$PWD/seqothello/jellyfish/$(basename "$f").kmer"
        BOUT="$PWD/seqothello/jellyfish/$(basename "$f").bin"
        #[ -e "$BOUT" ] && continue

        # -s [10M] initial Bloom filter size used in Jellyfish. You may need to use
        # larger values for real experiments.
        # -m 31 Length of kmers
        echo -n \
        $MCCORTEX view -q -k $f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fastq.awk \| \
            $JELLYFISH count -s 10M -m 31 -C -t 2 -o $JOUT /dev/stdin \&\& \
        $JELLYFISH dump -t -L 0 -c $JOUT -o $KOUT \&\& \
        $SEQOTHELLO/PreProcess --k=31 --cutoff=0 --in=$KOUT --out=$BOUT
        echo -ne "\\0"
    done
) | xargs -0 -r -n 1 -P $NCORES bash -c' \
    |& tee seqothello-jellyfish.log
fi

################################################################################

cd seqothello

ls jellyfish/*.bin | sed 's/^jellyfish\///' > docs.txt
split -d -l 50 docs.txt --additional-suffix=.txt docs-

run_exp "experiment=seqothello phase=group" bash -c '
(
    for g in docs-*.txt; do
        [ -e group-$g ] && continue

        echo -n \
            $SEQOTHELLO/Group --flist=$g --folder=jellyfish/ --output=group-$g
        echo -ne "\\0"
    done
) | xargs -0 -r -n 1 -P $NCORES bash -c' \
    |& tee ../seqothello-group.log

ls group-*.txt > listgroups.txt
mkdir -p map

run_exp "experiment=seqothello phase=build" bash -c '
    $SEQOTHELLO/Build --flist=listgroups.txt --out-folder=map/' \
    |& tee ../seqothello-build.log

save_size "experiment=seqothello phase=index" map \
    |& tee ../seqothello-indexsize.log

fi
################################################################################
# run queriesg on SEQOTHELLO

cd $DATADIR

for Q in 1 100 1000 10000; do
    run_exp "experiment=seqothello phase=query$Q.0" \
            $SEQOTHELLO/Query --map-folder=seqothello/map/ \
            --transcript=queries$Q.fa \
            --output=seqothello-results$Q.0.txt \
            --qthread=1 \
            >& seqothello-query$Q.0.log

    RESULT="experiment=seqothello dataset=$DATASET phase=check$Q.0" \
    perl $SCRIPT_DIR/check-seqothello-results.pl \
         queries$Q.fa seqothello-results$Q.0.txt \
         >& seqothello-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=seqothello phase=query$Q.1" \
            $SEQOTHELLO/Query --map-folder=seqothello/map/ \
            --transcript=queries$Q.fa \
            --output=seqothello-results$Q.1.txt \
            --qthread=1 \
            >& seqothello-query$Q.1.log

    RESULT="experiment=seqothello dataset=$DATASET phase=check$Q.1" \
    perl $SCRIPT_DIR/check-seqothello-results.pl \
         queries$Q.fa seqothello-results$Q.1.txt \
         >& seqothello-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=seqothello phase=query$Q.2" \
            $SEQOTHELLO/Query --map-folder=seqothello/map/ \
            --transcript=queries$Q.fa \
            --output=seqothello-results$Q.2.txt \
            --qthread=1 \
            >& seqothello-query$Q.2.log

    RESULT="experiment=seqothello dataset=$DATASET phase=check$Q.2" \
    perl $SCRIPT_DIR/check-seqothello-results.pl \
         queries$Q.fa seqothello-results$Q.2.txt \
         >& seqothello-check_results$Q.2.log

done

################################################################################
