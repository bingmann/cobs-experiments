#!/bin/bash -x
################################################################################
# Script to construct and query all indices
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

bash -c "$SCRIPT_DIR/create-sbt.sh"
bash -c "$SCRIPT_DIR/create-ssbt.sh"
bash -c "$SCRIPT_DIR/create-allsome.sh"
bash -c "$SCRIPT_DIR/create-howde.sh"
bash -c "$SCRIPT_DIR/create-mantis.sh"
bash -c "$SCRIPT_DIR/create-bigsi.sh"

################################################################################
