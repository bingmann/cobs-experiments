#!/bin/bash
################################################################################
# Script to convert a directory of compressed FastQ files to FastA
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SEQTK=${BASEDIR}/bin/seqtk
NCORES=$(grep -c ^processor /proc/cpuinfo)

(
    for file in fastq/*; do
        file=$(basename $file)
        [ -e "fasta/$file/.complete" ] && continue

        echo -n \
             mkdir -p fasta/$file \&\& \
             zcat fastq/$file/*.fastq.gz \| $SEQTK seq -A \| gzip -9 \> fasta/$file/$file.fasta.gz \&\& \
             echo fasta/$file/.complete \&\& \
             touch fasta/$file/.complete \&\& \
             rm -rv fastq/$file
        echo -ne '\0'
    done
) | xargs -0 -n1 -P $NCORES sh -c

################################################################################
