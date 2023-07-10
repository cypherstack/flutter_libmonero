#!/bin/sh

. ./config.sh

MONERO_URL="https://github.com/monero-project/monero.git"
MONERO_VERSION=v0.18.2.2
MONERO_SHA_HEAD=e06129bb4d1076f4f2cebabddcee09f1e9e30dcc
MONERO_SRC_DIR="${EXTERNAL_MACOS_SOURCE_DIR}/monero"
BUILD_TYPE=release
PREFIX=${EXTERNAL_MACOS_DIR}
DEST_LIB_DIR=${EXTERNAL_MACOS_LIB_DIR}/monero
DEST_INCLUDE_DIR=${EXTERNAL_MACOS_INCLUDE_DIR}/monero
ARCH=`uname -m`

echo "Cloning monero from - $MONERO_URL to - MONERO_SRC_DIR"
git clone ${MONERO_URL} ${MONERO_SRC_DIR} --branch ${MONERO_VERSION}
cd $MONERO_SRC_DIR
git checkout $MONERO_VERSION
git reset --hard $MONERO_SHA_HEAD
git submodule update --init --force
mkdir -p build
cd ..

mkdir -p $DEST_LIB_DIR
mkdir -p $DEST_INCLUDE_DIR

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z $INSTALL_PREFIX ]; then
    INSTALL_PREFIX=${ROOT_DIR}/monero
fi

echo "Building MACOS ${arch}"
export CMAKE_INCLUDE_PATH="${PREFIX}/include"
export CMAKE_LIBRARY_PATH="${PREFIX}/lib"

if [ "${ARCH}" == "x86_64" ]; then
	ARCH="x86-64"
fi

rm -r monero/build > /dev/null

mkdir -p monero/build/${BUILD_TYPE}
pushd monero/build/${BUILD_TYPE}
cmake -DARCH=${arch} \
  -DBUILD_64=ON \
	-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
	-DSTATIC=ON \
	-DBUILD_GUI_DEPS=ON \
	-DUNBOUND_INCLUDE_DIR=${EXTERNAL_MACOS_INCLUDE_DIR} \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}  \
  -DUSE_DEVICE_TREZOR=OFF \
	../..
make wallet_api -j$(nproc)
find . -path ./lib -prune -o -name '*.a' -exec cp '{}' lib \;
cp -r ./lib/* $DEST_LIB_DIR
cp ../../src/wallet/api/wallet2_api.h  $DEST_INCLUDE_DIR
popd