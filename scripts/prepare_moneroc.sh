#!/bin/bash

set -x -e

cd "$(dirname "$0")"

if [[ ! -d "monero_c" ]];
then
    git clone https://github.com/mrcyjanek/monero_c --branch rewrite-wip
    cd monero_c
    git checkout 1078ed22349b02c9f0e01d712821c1fe09553a0d
    git reset --hard
    git submodule update --init --force --recursive
    ./apply_patches.sh monero
    ./apply_patches.sh wownero
fi

echo "monero_c source prepared".