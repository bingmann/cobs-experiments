#!/bin/bash
################################################################################
# Script to fixup the BIGSI experiment set
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
NCORES=$(grep -c ^processor /proc/cpuinfo)

if [ "$(basename $PWD)" != "bigsi-data" -o ! -e "cortex" ]; then
    echo "Run in bigsi-data directory"
    exit
fi

# uncompress
if [ -e cortex/*/*/*.ctx.bz2 ]; then
    find -iname *.ctx.bz2 | xargs -P $NCORES -n 1 bunzip2 -v
fi

# check samples, rename uncleaned if cleaned exists
for f in cortex/*; do
    b=$(basename $f)
    if [ -e $f/cleaned/$b.ctx ]; then
        if [ -e $f/uncleaned/$b.ctx ]; then
            echo "Clean and unclean $b"
            mv -v $f/uncleaned/$b.ctx $f/uncleaned/$b.ctx.extra
        fi
    elif [ -e $f/uncleaned/$b.ctx ]; then
        echo "Only uncleaned $b"
    else
        echo "No cortex? $b"
    fi
done

################################################################################
