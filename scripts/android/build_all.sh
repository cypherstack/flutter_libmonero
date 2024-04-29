#!/bin/sh

# Usage: env USE_DOCKER= ./build_all.sh 

set -x -e

# Format git_versions.dart.
# echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> ../monero_c/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="LINUX"
sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE

cd "$(dirname "$0")"

if [[ "x$(uname)" == "xDarwin" ]];
then
    USE_DOCKER="ON"
fi

../prepare_moneroc.sh

# NOTE: -j1 is intentional. Otherwise you will run into weird behaviour on macos
if [[ ! "x$USE_DOCKER" == "x" ]];
then
    pushd ../monero_c
        # docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh monero x86_64-linux-android -j1"
        # docker run --platform linux/amd64 -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh monero i686-linux-android -j1"
        docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh monero arm-linux-androideabi -j1"
        docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh monero aarch64-linux-android -j1"
    popd
fi

unxz -f ../monero_c/release/monero/x86_64-linux-android_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/wownero/x86_64-linux-android_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/monero/arm-linux-androideabi_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/wownero/arm-linux-androideabi_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/monero/arm-linux-androideabi_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/wownero/arm-linux-androideabi_libwallet2_api_c.so.xz