#!/bin/bash -x
################################################################################
# Setup to set up software to run DNA index experiments: installs COBS, BIGSI,
# Mantis, SBT, SSBT, AllSome-SBT, HowDe-SBT, and many dependencies
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -e

BASEDIR=${HOME}/dna/
GITDATE="2019-04-10"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

NCORES=16

################################################################################
# SBT dependencies

build_sdsl() {
    [ -e "$BASEDIR/include/sdsl" ] && return

    cd $BASEDIR
    rm -rf sdsl-lite
    git clone https://github.com/simongog/sdsl-lite

    cd sdsl-lite/build/
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)

    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${BASEDIR}
    make -j $NCORES install
    make clean
}

build_jellyfish() {
    VER=2.2.10
    [ -e "$BASEDIR/include/jellyfish" ] && return

    cd $BASEDIR
    rm -rf jellyfish-$VER
    wget -c -O jellyfish-$VER.tar.gz \
         https://github.com/gmarcais/Jellyfish/releases/download/v$VER/jellyfish-$VER.tar.gz
    tar xzf jellyfish-$VER.tar.gz
    rm jellyfish-$VER.tar.gz

    cd jellyfish-$VER
    ./configure --prefix=$BASEDIR
    make -j $NCORES install
    make clean

    cd $BASEDIR/include
    ln -s jellyfish-$VER/jellyfish jellyfish
}

build_roaring() {
    VER=0.2.60
    [ -e "$BASEDIR/include/roaring" ] && return

    cd $BASEDIR
    rm -rf CRoaring-$VER
    wget -c -O CRoaring-$VER.tar.gz \
         https://github.com/RoaringBitmap/CRoaring/archive/v$VER.tar.gz
    tar xzf CRoaring-$VER.tar.gz
    rm CRoaring-$VER.tar.gz

    mkdir CRoaring-$VER/build
    cd CRoaring-$VER/build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${BASEDIR} \
          -DROARING_BUILD_STATIC=ON
    make -j $NCORES install
    make clean
}

build_htslib() {
    VER=1.9
    [ -e "$BASEDIR/include/htslib" ] && return

    cd $BASEDIR
    rm -rf htslib-$VER
    wget -c \
         https://github.com/samtools/htslib/releases/download/$VER/htslib-$VER.tar.bz2
    tar xkf htslib-$VER.tar.bz2
    rm htslib-$VER.tar.bz2

    cd htslib-$VER
    ./configure --prefix=$BASEDIR
    make -j $NCORES install
    make clean
}

build_ntCard() {
    VER=1.1.0
    [ -e "$BASEDIR/bin/ntcard" ] && return

    cd $BASEDIR
    rm -rf htslib-$VER
    wget -c -O ntCard-$VER.tar.gz \
         https://github.com/bcgsc/ntCard/archive/v$VER.tar.gz
    tar xzf ntCard-$VER.tar.gz
    rm ntCard-$VER.tar.gz

    cd ntCard-$VER
    ./autogen.sh
    ./configure --prefix=$BASEDIR
    make -j $NCORES install
    make clean
}

################################################################################
# Various SBT Variants

build_sbt() {
    build_sdsl
    build_jellyfish

    cd $BASEDIR
    rm -rf bloomtree
    git clone https://github.com/Kingsford-Group/bloomtree
    cd bloomtree/src
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)
    export PKG_CONFIG_PATH=$BASEDIR/lib/pkgconfig
    make -j $NCORES
}

# Build Split Sequence Bloom Tree
build_ssbt() {
    build_sdsl
    build_jellyfish
    build_htslib

    cd $BASEDIR
    rm -rf splitsbt
    git clone https://github.com/Kingsford-Group/splitsbt
    cd splitsbt/src
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)
    export PKG_CONFIG_PATH=$BASEDIR/lib/pkgconfig
    make -j $NCORES
}

# Build AllSome Sequence Bloom Tree
build_allsome() {
    build_sdsl
    build_jellyfish
    build_roaring

    cd $BASEDIR
    rm -rf bloomtree-allsome
    git clone https://github.com/medvedevgroup/bloomtree-allsome
    cd bloomtree-allsome
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)
    # apply fix for changes in roaring
    patch -p1 < ${SCRIPT_DIR}/setup-bloomtree-allsome.patch
    cd src
    make -j $NCORES HOME=${BASEDIR}
    cd ../bfcluster
    make -j $NCORES HOME=${BASEDIR}
}

# Build HowDe Sequence Bloom Tree
build_howde() {
    build_sdsl
    build_jellyfish
    build_roaring
    build_ntCard

    cd $BASEDIR
    rm -rf HowDeSBT
    git clone https://github.com/medvedevgroup/HowDeSBT
    cd HowDeSBT
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)
    make -j $NCORES HOME=${BASEDIR}
}

################################################################################
# Squeakr and Mantis

build_squeakr() {
    [ -e $BASEDIR/squeakr/squeakr ] && return

    cd $BASEDIR
    rm -rf squeakr
    git clone https://github.com/splatlab/squeakr.git
    cd squeakr
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)
    make -j $NCORES
}

build_mantis() {
    [ -e $BASEDIR/mantis/mantis ] && return
    build_squeakr
    build_sdsl

    cd $BASEDIR
    rm -rf mantis
    git clone https://github.com/splatlab/mantis.git
    mkdir mantis/build
    cd mantis/build
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)
    cmake .. \
          -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${BASEDIR} \
          -DSDSL_INSTALL_PATH=${BASEDIR}
    make -j $NCORES
}

################################################################################
# BIGSI, Cortex, and dependencies

build_mccortex() {
    [ -e $BASEDIR/mccortex/bin/mccortex31 ] && return

    cd $BASEDIR
    rm -rf mccortex
    git clone --recursive https://github.com/mcveanlab/mccortex.git
    cd mccortex
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)
    git submodule update
    make -j $NCORES
}

build_berkeleydb() {
    BERKELEY_VERSION=4.8.30
    [ -e $BASEDIR/include/db.h ] && return

    cd $BASEDIR
    # Download, configure and install BerkeleyDB
    rm -rf db-"${BERKELEY_VERSION}"
    wget -c http://download.oracle.com/berkeley-db/db-"${BERKELEY_VERSION}".tar.gz
    tar xzf db-"${BERKELEY_VERSION}".tar.gz
    rm db-"${BERKELEY_VERSION}".tar.gz

    cd db-"${BERKELEY_VERSION}"/build_unix
    ../dist/configure --prefix ${BASEDIR} && make -j $NCORES && make install
}

build_rocksdb() {
    VER=5.18.3
    [ -e $BASEDIR/include/rocksdb ] && return

    cd $BASEDIR
    rm -rf rocksdb-$VER
    wget -c -O rocksdb-$VER.tar.gz \
         https://github.com/facebook/rocksdb/archive/v$VER.tar.gz
    tar xzf rocksdb-$VER.tar.gz
    rm rocksdb-$VER.tar.gz

    mkdir rocksdb-$VER/build
    cd rocksdb-$VER/build
    cmake .. -DCMAKE_INSTALL_PREFIX=${BASEDIR} -DWITH_SNAPPY=YES
    make -j $NCORES install
    make clean
}

build_bigsi() {
    build_berkeleydb
    build_rocksdb

    cd $BASEDIR

    rm -rvf bigsi
    virtualenv -p python3 bigsi
    cd bigsi

    echo "export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}\${LD_LIBRARY_PATH:+:}${BASEDIR}/lib" >> bin/activate
    source bin/activate

    git clone https://github.com/Phelimb/BIGSI.git
    cd BIGSI
    git checkout $(git rev-list -n 1 --before="$GITDATE" master)

    export BERKELEYDB_DIR=${BASEDIR}
    pip3 install bsddb3

    export CPLUS_INCLUDE_PATH=${CPLUS_INCLUDE_PATH}${CPLUS_INCLUDE_PATH:+:}${BASEDIR}/include
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}${LD_LIBRARY_PATH:+:}${BASEDIR}/lib
    export LIBRARY_PATH=${LIBRARY_PATH}${LIBRARY_PATH:+:}${BASEDIR}/lib
    pip3 install python-rocksdb

    pip3 install -r requirements.txt
    pip3 install -r optional-requirements.txt
    pip3 install .
}

################################################################################

build_all() {
    build_sbt
    build_ssbt
    build_allsome
    build_howde
    build_mantis
    build_bigsi
}

$1

################################################################################
