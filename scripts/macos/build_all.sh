#!/bin/sh

set -x -e

cd "$(dirname "$0")"

if [[ ! "x$(uname)" == "xDarwin" ]];
then
    echo "Only Darwin hosts can build macos";
    exit 1
fi

../prepare_moneroc.sh
pushd ../monero_c
    ./build_single.sh monero host-apple-darwin -j8
    ./build_single.sh wownero host-apple-darwin -j8
popd

unxz -f ../monero_c/release/monero/host-apple-darwin_libwallet2_api_c.dylib.xz
unxz -f ../monero_c/release/wownero/host-apple-darwin_libwallet2_api_c.dylib.xz