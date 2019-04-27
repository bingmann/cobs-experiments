#!/bin/bash -x
################################################################################
# Script to construct and query all indices
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

for f in bigsi-data100 bigsi-data250 bigsi-data500 bigsi-data1000 bigsi-data2500 bigsi-data5000 bigsi-data; do
    cd /data01/bingmann/$f
    $SCRIPT_DIR/batch.sh
done

################################################################################
