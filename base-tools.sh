#!/bin/bash -x
################################################################################
# Base Tools
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

BASEDIR=${HOME}/dna

# run experiment and log disk and cpu cycles
run_exp() {
    exp=$1
    shift

    # drop disk caches, get current counters
    sync
    /usr/bin/setuid-drop-disk-caches
    before_reads=$(awk '$3 ~ /^md0$/ { print $6 }' /proc/diskstats)
    before_writes=$(awk '$3 ~ /^md0$/ { print $10 }' /proc/diskstats)
    before_fill=$(df /dev/md0 | awk '/md0/ { print $3 }')

    /usr/bin/time \
        -f "RESULT $exp info=time time=%e usertime=%U systime=%S rss=%M" \
        "$@"

    sync
    after_reads=$(awk '$3 ~ /^md0$/ { print $6 }' /proc/diskstats)
    after_writes=$(awk '$3 ~ /^md0$/ { print $10 }' /proc/diskstats)
    after_fill=$(df /dev/md0 | awk '/md0/ { print $3 }')

    read=$(((after_reads - before_reads) * 512))
    write=$(((after_writes - before_writes) * 512))
    fill=$(((after_fill - before_fill) * 1024))
    echo "RESULT $exp info=disks read=$read write=$write fill=$fill"
}

################################################################################
