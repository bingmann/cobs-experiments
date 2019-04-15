#!/bin/bash
################################################################################
# Script to prepare subsets of the SBT experiment set
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ "$(basename $PWD)" != "sbt-data" -o ! -e "fasta" ]; then
    echo "Run in sbt-data directory"
    exit
fi

for s in 10 100 250 500 1000; do
    mkdir -p ../sbt-data$s/fasta/

    for f in $(cat $SCRIPT_DIR/list-sbt-data-$s.txt); do
        cp -avl fasta/$f ../sbt-data$s/fasta/
    done
done

################################################################################
