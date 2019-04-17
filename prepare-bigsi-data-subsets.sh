#!/bin/bash
################################################################################
# Script to prepare subsets of the BIGSI experiment set
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ "$(basename $PWD)" != "bigsi-data" -o ! -e "cortex" ]; then
    echo "Run in bigsi-data directory"
    exit
fi

for s in 100 250 500 1000 2500 5000; do
    mkdir -p ../bigsi-data$s/cortex/

    for f in $(cat $SCRIPT_DIR/list-bigsi-data-$s.txt); do
        cp -avl cortex/$f ../bigsi-data$s/cortex/
    done
done

################################################################################
