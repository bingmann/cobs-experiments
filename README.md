# Experiment Scripts for COBS as Reported in arXiv:1905.09624

This repository contains a set of scripts to run the experiments reported in [arXiv:1905.09624](https://arxiv.org/abs/1905.09624) on eight k-mer index software packages:
SBT, Split-SBT, AllSome-SBT, HowDe-SBT, SeqOthello, Mantis, BIGSI, and COBS.

It currently contains downloading scripts for the one microbial dataset in McCortex format referenced in the paper.
We plan to rerun the experiments with the SBT experiment dataset in Fasta format.

The experiments were run on an Ubuntu 18.04 Bionic system.

## Step 1: Software Setup

Clone the scripts repository:
```
git clone https://github.com/bingmann/cobs-experiments.git
```
And download and build the index software packages in `$HOME/dna/`
```
cd cobs-experiments
./setup.sh build_all
```
The setup.sh script fetches and compiles specific versions of the index software packages.
If any build fails you can check your build environment (e.g. install more development packages from the distro) and rerun the script parts.

Finally, check that `$HOME/dna/` contains the following software packages:
```
CRoaring-0.2.60  bigsi      bloomtree-allsome  htslib-1.9    lib           rocksdb-6.0.2  share
HowDeSBT         bin        db-4.8.30          include       mantis        sdsl-lite      splitsbt
SeqOthello       bloomtree  docs               jellyfish-2.2.10            ntCard-1.1.0   seqtk-1.3
squeakr
```

Next, install the `setuid-drop-disk-caches` tool, which is used to clear the disk caches in the Linux kernel prior to each experiment.
The tool must be compiled and installed with setuid root flag:
```
gcc -O3 -o setuid-drop-disk-caches setuid-drop-disk-caches.c
sudo cp setuid-drop-disk-caches /usr/bin/setuid-drop-disk-caches
sudo chown root:root /usr/bin/setuid-drop-disk-caches
sudo chmod u+s /usr/bin/setuid-drop-disk-caches
```

## Step 2: Data Download

You need a large local disk to store the dataset, we will consider this as `/mnt`.
To fetch a part of the microbial data from the ENA FTP server you can use the downloader script:
```
cd /mnt/
mkdir -p microbial-data100/cortex
cd microbial-data100
~/cobs-experiments/fetch-microbial-data.sh ~/cobs-experiments/list-microbial-data-100.txt
~/cobs-experiments/prepare-microbial-data-fixup.sh
```
The script runs with 4 parallel downloader threads, the output files must go into a `cortex` subdirectory.
The `list-microbial-data-100.txt` is the smallest dataset, and shown here only as an example.
The number in the file name is the number of documents.
If any download fails, simply rerun the fetcher script.

After downloading the dataset must be "unpacked" and fixed in various ways. 
This is easily performed by running `prepare-microbial-data-fixup.sh`.
This deletes unnecessary files, decompresses `.ctx.bz2` files and checks that each directory contains one McCortex file.

To download the entire dataset, fetch the `list-microbial-data.txt` file. This requires about 4 TiB of storage. The smaller subset can then be constructed without extra space usage using hardlinks by running `prepare-microbial-data-subsets.sh`.

The `microbial-data100` cortex files are around 4 GiB when downloaded.

## Step 3: Running Index Experiments

First create random queries:
```
cd /mnt/microbial-data100/
~/cobs-experiments/create-queries.sh
```

And then run the experiments for the individual software packages:
```
cd /mnt/microbial-data100/
~/cobs-experiments/run-sbt.sh
~/cobs-experiments/run-ssbt.sh
~/cobs-experiments/run-allsome.sh
~/cobs-experiments/run-howde.sh
~/cobs-experiments/run-seqothello.sh
~/cobs-experiments/run-mantis.sh
~/cobs-experiments/run-bigsi.sh
~/cobs-experiments/run-cobs_classic.sh
~/cobs-experiments/run-cobs_compact.sh

```
The output of each experiment and phase is logged into `*.log` files containing `RESULT` lines which were further processed to create the plots in the paper.

## Exits

Written 2019-06-11 by Timo Bingmann
