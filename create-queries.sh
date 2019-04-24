#!/bin/bash -x
################################################################################
# Script to construct queries using mccortex and COBS
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

################################################################################
# generate unitig fasta files

if [ -e fasta ]; then
    K=20
    echo "FIXME"
    exit
elif [ -e cortex ]; then
    K=31

    export MCCORTEX NCORES
    run_exp "experiment=queries phase=unitigs" bash -c "
(
    for f in cortex/*/*/*.ctx; do
        OUT=\"unitigs/\$f.fa.gz\"
        [ -e \"\$OUT\" ] && continue
        # mkdir for OUT
        install -D /dev/null \"\$OUT\"

        echo -n \
            $MCCORTEX unitigs \$f \| gzip -9 \> \$OUT.tmp \&\& \
            mv \$OUT.tmp \$OUT
        echo -ne \"\\0\"
    done
) | xargs -0 -r -n 1 -P $NCORES sh -c" \
    |& tee queries-unitigs.log

fi

################################################################################
# select queries from unitig Fasta files

if [ ! -e queries1.fa ]; then
    # select single k-mer queries directly from cortex
    $COBS generate-queries cortex --positive 100000 --negative 100000 \
          -k $K -N -o queries1.fa \
        |& tee queries-generate1.log
    grep -v '^>' queries1.fa > queries1-plain.fa
fi

if [ ! -e queries100.fa ]; then
    # queries with 100 length from unitig fasta files
    $COBS generate-queries unitigs --positive 100000 --negative 100000 \
          -k 100 -N -o queries100.fa \
        |& tee queries-generate100.log
    grep -v '^>' queries100.fa > queries100-plain.fa
fi

if [ ! -e queries1000.fa ]; then
    # queries with 1000 length from unitig fasta files
    $COBS generate-queries unitigs --positive 10000 --negative 10000 \
          -k 1000 -N -o queries1000.fa \
        |& tee queries-generate1000.log
    grep -v '^>' queries1000.fa > queries1000-plain.fa
fi

if [ ! -e queries10000.fa ]; then
    # queries with 1000 length from unitig fasta files
    $COBS generate-queries unitigs --positive 1000 --negative 1000 \
          -k 10000 -N -o queries10000.fa \
        |& tee queries-generate10000.log
    grep -v '^>' queries10000.fa > queries10000-plain.fa
fi

################################################################################
