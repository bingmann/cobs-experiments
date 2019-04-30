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

make_sublist() {
    if [ ! -e $SCRIPT_DIR/list-bigsi-data-$1.txt ]; then
        sort -R $SCRIPT_DIR/list-bigsi-$2.txt \
            | tail -n $1 \
            > $SCRIPT_DIR/list-bigsi-data-$1.txt
    fi
}

expand_list() {
    if [ ! -e $SCRIPT_DIR/list-bigsi-data-$2.txt ]; then
        cp $SCRIPT_DIR/list-bigsi-data-$1.txt $SCRIPT_DIR/list-bigsi-data-$2.txt
        while true; do
            EX=$(wc -l $SCRIPT_DIR/list-bigsi-data-$2.txt | cut -d ' ' -f 1)
            [ $EX == $2 ] && break
            EX=$(($2 - EX))
            sort -R $SCRIPT_DIR/list-bigsi-data.txt | tail -n $EX | cat - $SCRIPT_DIR/list-bigsi-data-$2.txt | sort | uniq > $SCRIPT_DIR/list-bigsi-data-$2-new.txt
            mv $SCRIPT_DIR/list-bigsi-data-$2-new.txt $SCRIPT_DIR/list-bigsi-data-$2.txt
        done
        wc -l $SCRIPT_DIR/list-bigsi-data-$2.txt
    fi
}

expand_list 50000 100000
expand_list 25000 50000
expand_list 10000 25000

make_sublist 5000 data
make_sublist 2500 data-5000
make_sublist 1000 data-2500
make_sublist 500 data-1000
make_sublist 250 data-500
make_sublist 100 data-250

for s in 100 250 500 1000 2500 5000; do
    mkdir -p ../bigsi-data$s/cortex/

    for f in $(cat $SCRIPT_DIR/list-bigsi-data-$s.txt); do
        cp -avl cortex/$f ../bigsi-data$s/cortex/
    done
done

################################################################################
