#!/bin/bash
################################################################################
# Scripts to download all FastQ sample files used in SBT paper, as listed in
# list-sbt-experiments.txt from
# ftp://ftp.sra.ebi.ac.uk/vol1/fastq/
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

LIST=$(cat $SCRIPT_DIR/list-sbt-data.txt)

(
    for l in $LIST; do
        #echo $l
        [ -e "$l/.complete" ] && continue

        if [ ${#l} == 9 ]; then
            echo -n \
                 wget -nv -m -c -nH --cut-dirs=3 \
                 ftp://ftp.sra.ebi.ac.uk/vol1/fastq/${l:0:6}/$l/ \
                 \&\& touch $l/.complete
        elif [ ${#l} == 10 ]; then
            echo -n \
                 wget -nv -m -c -nH --cut-dirs=4 \
                 ftp://ftp.sra.ebi.ac.uk/vol1/fastq/${l:0:6}/00${l:9:1}/$l/ \
                 \&\& touch $l/.complete
        fi
        echo -ne '\0'
    done
) | xargs -0 -n1 -P4 sh -c

################################################################################
