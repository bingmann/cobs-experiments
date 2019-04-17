#!/bin/bash
################################################################################
# Script to download all cortex sample files used in BIGSI paper, as listed in
# list-bigsi-samples.txt from
# ftp://ftp.ebi.ac.uk/pub/software/bigsi/nat_biotech_2018/
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

LIST=$(cat $SCRIPT_DIR/list-bigsi-data.txt)

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
) | xargs -0 -n1 -P4 sh -c

################################################################################
