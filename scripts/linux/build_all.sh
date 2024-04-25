#!/bin/bash

set -x -e

cd "$(dirname "$0")"

if [[ ! "x$(uname)" == "xLinux" ]];
then
    echo "Only Linux hosts can build linux";
    exit 1
fi

../prepare_moneroc.sh
pushd ../monero_c
    ./build_single.sh monero x86_64-linux-gnu -j8
    ./build_single.sh wownero x86_64-linux-gnu -j8
popd

unxz -f ../monero_c/release/monero/x86_64-linux-gnu_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/wownero/x86_64-linux-gnu_libwallet2_api_c.so.xz