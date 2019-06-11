#!/bin/bash
################################################################################
# Script to fixup the Microbial experiment set
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
NCORES=$(grep -c ^processor /proc/cpuinfo)

if [[ "$(basename $PWD)" != microbial-data* || ! -e "cortex" ]]; then
    echo "Run in microbial-data directory"
    exit
fi

# delete stuff
find -iname *.bloom* -ls -delete
find -iname *.csv* -ls -delete
find -iname *.ctx_braken.report* -ls -delete
find -iname *.ctx_kraken.report* -ls -delete
find -iname *.ctx_kraken_bracken.report* -ls -delete
find -iname *.log* -ls -delete
find -iname *.msh* -ls -delete
find -iname *.out* -ls -delete

# uncompress
find -iname *.ctx.bz2 | xargs -r -P $NCORES -n 1 bunzip2 -vf

# check samples, rename uncleaned if cleaned exists
for f in cortex/*; do
    b=$(basename $f)
    if [ -e $f/cleaned/$b.ctx ]; then
        if [ -e $f/uncleaned/$b.ctx ]; then
            echo "Clean and unclean $b"
            rm $f/uncleaned/$b.ctx
        fi
        FSIZE=$(stat -c %s "$f/cleaned/$b.ctx")
        if [ "$FSIZE" == "0" ]; then
            echo "Zero sized $b"
        fi
    elif [ -e $f/uncleaned/$b.ctx ]; then
        echo "Only uncleaned $b"
    else
        echo "No cortex? $b"
        rm -v $f/.complete
    fi
done

################################################################################
