#!/bin/bash

set -x -e

VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="WINDOWS"
sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE

cd "$(dirname "$0")"

if [[ ! "x$(uname)" == "xLinux" ]];
then
    echo "Only Linux hosts can build windows (yes, i know)";
    exit 1
fi

../prepare_moneroc.sh "060c27f91e23d7123e0eae535756212b81574ae6"

# export USE_DOCKER="ON"

pushd ../monero_c
    set +e
    command -v sudo && export SUDO=sudo
    set -e
    NPROC="-j$(nproc)"
    if [[ ! "x$USE_DOCKER" == "x" ]];
    then
        for COIN in monero wownero;
        do
            $SUDO docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 gperf libtinfo5; ./build_single.sh ${COIN} x86_64-w64-mingw32 $NPROC"
            # $SUDO docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc-mingw-w64-i686 g++-mingw-w64-i686 gperf libtinfo5; ./build_single.sh ${COIN} i686-w64-mingw32 $NPROC"
        done
    else
        for COIN in monero wownero;
        do
            $SUDO ./build_single.sh ${COIN} x86_64-w64-mingw32 $NPROC
            # $SUDO ./build_single.sh ${COIN} i686-w64-mingw32 $NPROC
        done
    fi
popd

unxz -f ../monero_c/release/monero/*.dll.xz
unxz -f ../monero_c/release/wownero/*.dll.xz
