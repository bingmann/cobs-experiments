#!/bin/bash -x
################################################################################
# Script to construct an AllSome Sequence Bloom Tree from FASTQ and run some queries
#
# Copyright (C) 2019 Timo Bingmann <tb@panthema.net>
################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $SCRIPT_DIR/base-tools.sh

export LD_LIBRARY_PATH=${HOME}/dna/lib

BT=${BASEDIR}/bloomtree-allsome/src/bt
SBUILD=${BASEDIR}/bloomtree-allsome/bfcluster/sbuild

DATADIR=$PWD

################################################################################
# use ntcard to estimate bloom filter size

if [ -e fasta ]; then
    K=20
    if [ ! -e "allsome_freq_k$K.hist" ]; then

        run_exp "experiment=allsome phase=ntcard" \
                $NTCARD --kmer=$K --threads=$NCORES --pref=allsome_freq fastq/*/*.fastq.gz \
            |& tee allsome-ntcard.log
    fi
elif [ -e cortex ]; then
    K=31
    if [ ! -e "allsome_freq_k$K.hist" ]; then

        run_exp "experiment=allsome phase=ntcard" bash -c "
            (for f in cortex/*/*/*.ctx; do $MCCORTEX view -q -k \$f; done) \
            | awk -f $SCRIPT_DIR/cortex-to-fasta.awk \
            | $NTCARD --kmer=$K --threads=$NCORES --pref=allsome_freq /dev/stdin" \
            |& tee allsome-ntcard.log
    fi
fi

occ=$(awk '$1 ~ /^F0$/ { print $2 }' allsome_freq_k$K.hist)
occ1=$(awk '$1 ~ /^F1$/ { print $2 }' allsome_freq_k$K.hist)

# README says to use F0 - F1 if cutoff is 1
BF_SIZE=$occ

mkdir -p allsome

# create jellyfish hash file
[ -e "allsome/hashfile.hh" ] || $BT hashes --k $K allsome/hashfile.hh 1

if [ ! -e allsome/allsome.sbt ] ; then
################################################################################
# construct bloom filters in parallel

if [ -e fasta ]; then

    export BT BF_SIZE NCORES
    run_exp "experiment=allsome phase=bloom" bash -c '
(
    for f in fastq/*; do
        OUT="allsome/$(basename "$f").bf.bv"
        [ -e "$OUT" ] && continue

        echo -n \
            zcat "$f/*.gz" \| seqtk seq -A \| \
            $BT count --cutoff 0 --threads 4 allsome/hashfile.hh "${BF_SIZE}" /dev/stdin "$OUT"
        echo -ne "\\0"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c' \
    |& tee allsome-make_bf.log

elif [ -e cortex ]; then

    export K BT BF_SIZE MCCORTEX NCORES
    run_exp "experiment=allsome phase=bloom" bash -c "
(
    for f in cortex/*; do
        OUT=\"allsome/\$(basename \$f).bf.bv\"
        #[ -e \"\$OUT\" ] && continue

        echo -n \
            $MCCORTEX view -q -k \$f/*/*.ctx \| \
            awk -f $SCRIPT_DIR/cortex-to-fasta.awk \| \
            $BT count --cutoff 0 --threads 4 allsome/hashfile.hh ${BF_SIZE} /dev/stdin \$OUT
        echo -ne \"\\0\"
    done
) | xargs -0 -n 1 -P $((NCORES / 4)) sh -c" \
    |& tee allsome-make_bf.log

fi

################################################################################
# construct and compress ALLSOME

cd allsome

ls *.bf.bv > listoffiles.txt
sed -i 's/\.bf\.bv$//' listoffiles.txt

run_exp "experiment=allsome phase=build" \
        bash -c "($SBUILD -f hashfile.hh -p . -o . -l listoffiles.txt -b tree.sbt &&
                  $BT split tree.sbt split.sbt)" \
    |& tee ../allsome-build.log

export BT NCORES
run_exp "experiment=allsome phase=compress" bash -c "
(
    for f in *.bf-all.bv; do
        echo -n \
            $BT compress-rrr-double \
            hashfile.hh \$f \${f%%.bf-all.bv}.bf-some.bv \${f%%.bf-all.bv}.bf-allsome.bv
        echo -ne \"\\0\"
    done
) | xargs -0 -n 1 -P $NCORES sh -c" \
    |& tee ../allsome-compress.log

# create the topology file for the compressed SBT-AS.
cat tree.sbt \
  | sed "s/\.bf\.bv$/.bf-allsome.bv.rrr/" \
  | sed "s/\*.\//*/" \
  > allsome.sbt

save_size "experiment=allsome phase=index" \
          allsome.sbt *.rrr \
    |& tee ../allsome-indexsize.log

# create the topology file for the compressed SBT-AS.
cat tree.sbt \
  | sed "s/\.bf\.bv/.bf-allsome.bv.rrr/" \
  | sed "s/\*.\//*/" \
  > allsome.sbt

fi
################################################################################
# run queries on ALLSOME

cd $DATADIR

for Q in 1 100 1000 10000; do
    # for SBTs, the threshold is the % of kmers in the query having to match: 50%
    # due to expansion with 1 random character

    run_exp "experiment=allsome phase=query$Q.0" \
            $BT query --query-threshold 0.9 \
            allsome/allsome.sbt queries$Q.fa allsome-results$Q.0.txt \
            >& allsome-query$Q.0.log

    RESULT="experiment=allsome dataset=$DATASET phase=check$Q.0" \
    perl $SCRIPT_DIR/check-allsome-results.pl queries$Q.fa allsome-results$Q.0.txt \
         >& allsome-check_results$Q.0.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=allsome phase=query$Q.1" \
            $BT query --query-threshold 0.9 \
            allsome/allsome.sbt queries$Q.fa allsome-results$Q.1.txt \
            >& allsome-query$Q.1.log

    RESULT="experiment=allsome dataset=$DATASET phase=check$Q.1" \
    perl $SCRIPT_DIR/check-allsome-results.pl queries$Q.fa allsome-results$Q.1.txt \
         >& allsome-check_results$Q.1.log

    NO_DROP_CACHE=1 \
    run_exp "experiment=allsome phase=query$Q.2" \
            $BT query --query-threshold 0.9 \
            allsome/allsome.sbt queries$Q.fa allsome-results$Q.2.txt \
            >& allsome-query$Q.2.log

    RESULT="experiment=allsome dataset=$DATASET phase=check$Q.2" \
    perl $SCRIPT_DIR/check-allsome-results.pl queries$Q.fa allsome-results$Q.2.txt \
         >& allsome-check_results$Q.2.log

done

################################################################################
