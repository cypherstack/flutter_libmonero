#!/bin/bash

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
OS="ANDROID"
sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE

cd "$(dirname "$0")"

NPROC="-j$(nproc)"

if [[ "x$(uname)" == "xDarwin" ]];
then
    USE_DOCKER="ON"
    NPROC="-j1"
fi

../prepare_moneroc.sh

# NOTE: -j1 is intentional. Otherwise you will run into weird behaviour on macos
if [[ ! "x$USE_DOCKER" == "x" ]];
then
    for COIN in monero wownero;
    do
        pushd ../monero_c
            docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh ${COIN} x86_64-linux-android $NPROC"
            # docker run --platform linux/amd64 -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh ${COIN} i686-linux-android $NPROC"
            docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh ${COIN} arm-linux-androideabi $NPROC"
            docker run --platform linux/amd64 -v$HOME/.cache/ccache:/root/.ccache -v$PWD:$PWD -w $PWD --rm -it git.mrcyjanek.net/mrcyjanek/debian:buster bash -c "git config --global --add safe.directory '*'; apt update; apt install -y ccache gcc g++ libtinfo5 gperf; ./build_single.sh ${COIN} aarch64-linux-android $NPROC"
        popd
    done
else
    for COIN in monero wownero;
    do
        pushd ../monero_c
            ./build_single.sh ${COIN} x86_64-linux-android $NPROC
            # ./build_single.sh ${COIN} i686-linux-android $NPROC
            ./build_single.sh ${COIN} armv7a-linux-androideabi $NPROC
            ./build_single.sh ${COIN} aarch64-linux-android $NPROC
        popd
    done
fi

unxz -f ../monero_c/release/monero/x86_64-linux-android_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/wownero/x86_64-linux-android_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/monero/armv7a-linux-androideabi_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/wownero/armv7a-linux-androideabi_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/monero/aarch64-linux-android_libwallet2_api_c.so.xz
unxz -f ../monero_c/release/wownero/aarch64-linux-android_libwallet2_api_c.so.xz

ln -s $(realpath ../monero_c/release/monero/aarch64-linux-android_libwallet2_api_c.so) ../../../../android/app/src/main/jniLibs/arm64-v8a/libmonero_libwallet2_api_c.so || true
ln -s $(realpath ../monero_c/release/wownero/aarch64-linux-android_libwallet2_api_c.so) ../../../../android/app/src/main/jniLibs/arm64-v8a/libwownero_libwallet2_api_c.so || true
ln -s $(realpath ../monero_c/release/monero/armv7a-linux-androideabi_libwallet2_api_c.so) ../../../../android/app/src/main/jniLibs/armeabi-v7a/libmonero_libwallet2_api_c.so || true
ln -s $(realpath ../monero_c/release/wownero/armv7a-linux-androideabi_libwallet2_api_c.so) ../../../../android/app/src/main/jniLibs/armeabi-v7a/libwownero_libwallet2_api_c.so || true
ln -s $(realpath ../monero_c/release/monero/x86_64-linux-android_libwallet2_api_c.so) ../../../../android/app/src/main/jniLibs/x86_64/libmonero_libwallet2_api_c.so || true
ln -s $(realpath ../monero_c/release/wownero/x86_64-linux-android_libwallet2_api_c.so) ../../../../android/app/src/main/jniLibs/x86_64/libwownero_libwallet2_api_c.so || true
