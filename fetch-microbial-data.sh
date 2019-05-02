#!/bin/bash
################################################################################
# Script to download all cortex sample files used in BIGSI paper, as listed in
# list-microbial-samples.txt from
# ftp://ftp.ebi.ac.uk/pub/software/bigsi/nat_biotech_2018/
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ ! -e $1 ]; then
    echo "Please pass an accession list"
    exit
fi

if [ -e cortex ]; then
    cd cortex
fi

LIST=$(cat $1)

(
    for l in $LIST; do
        #echo $l
        [ -e "$l/.complete" ] && continue

        echo -n \
             wget -nv -m -c -nH --cut-dirs=6 \
             ftp://ftp.ebi.ac.uk/pub/software/bigsi/nat_biotech_2018/ctx/${l:0:6}/$l/ \
             \&\& touch $l/.complete
        echo -ne '\0'
    done
) | xargs -0 -r -n1 -P4 sh -c

################################################################################
