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

make_list() {
    if [ ! -e $SCRIPT_DIR/list-bigsi-data-$1.txt ]; then
        sort -R $SCRIPT_DIR/list-bigsi-$2.txt \
            | tail -n $1 \
            > $SCRIPT_DIR/list-bigsi-data-$1.txt
    fi
}

make_list 5000 data
make_list 2500 data-5000
make_list 1000 data-2500
make_list 500 data-1000
make_list 250 data-500
make_list 100 data-250

for s in 100 250 500 1000 2500 5000; do
    mkdir -p ../bigsi-data$s/cortex/

    for f in $(cat $SCRIPT_DIR/list-bigsi-data-$s.txt); do
        cp -avl cortex/$f ../bigsi-data$s/cortex/
    done
done

################################################################################
