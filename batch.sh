#!/bin/bash -x
################################################################################
# Script to construct and query all indices
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

bash -c "$SCRIPT_DIR/create-queries.sh"

bash -c "$SCRIPT_DIR/run-sbt.sh"
bash -c "$SCRIPT_DIR/run-ssbt.sh"
bash -c "$SCRIPT_DIR/run-allsome.sh"
bash -c "$SCRIPT_DIR/run-howde.sh"
bash -c "$SCRIPT_DIR/run-mantis.sh"
bash -c "$SCRIPT_DIR/run-seqothello.sh"
bash -c "$SCRIPT_DIR/run-bigsi.sh"
bash -c "$SCRIPT_DIR/run-cobs.sh"

################################################################################
