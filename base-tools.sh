#!/bin/bash -x
################################################################################
# Base Tools
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

BASEDIR=${HOME}/dna

COBS=${BASEDIR}/cobs/b135/src/cobs
NTCARD=${BASEDIR}/bin/ntcard
MCCORTEX=${BASEDIR}/mccortex/bin/mccortex31

NCORES=$(grep -c ^processor /proc/cpuinfo)

DATASET=$(basename $PWD)

# run experiment and log disk and cpu cycles
run_exp() {
    exp=$1
    shift

    # drop disk caches, get current counters
    sync
    [ $NO_DROP_CACHE ] || /usr/bin/setuid-drop-disk-caches
    before_reads=$(awk '$3 ~ /^md0$/ { print $6 }' /proc/diskstats)
    before_writes=$(awk '$3 ~ /^md0$/ { print $10 }' /proc/diskstats)
    before_fill=$(df /dev/md0 | awk '/md0/ { print $3 }')

    /usr/bin/time \
        -f "RESULT $exp info=time dataset=$DATASET time=%e usertime=%U systime=%S rss=%M" \
        "$@"

    sync
    after_reads=$(awk '$3 ~ /^md0$/ { print $6 }' /proc/diskstats)
    after_writes=$(awk '$3 ~ /^md0$/ { print $10 }' /proc/diskstats)
    after_fill=$(df /dev/md0 | awk '/md0/ { print $3 }')

    read=$(((after_reads - before_reads) * 512))
    write=$(((after_writes - before_writes) * 512))
    fill=$(((after_fill - before_fill) * 1024))
    echo "RESULT $exp info=disk dataset=$DATASET read=$read write=$write fill=$fill" > /dev/stderr
}

# calculate total size of files listed and output a RESULT line
save_size() {
    exp=$1
    shift

    # determine total file size
    SIZE=$(du -ac "$@" | tail -n 1 | cut -f 1)

    echo "RESULT $exp info=size dataset=$DATASET size=$SIZE" > /dev/stderr
}

################################################################################
