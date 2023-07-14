#!/bin/sh

. ./config.sh

WOWNERO_URL="https://git.wownero.com/wownero/wownero.git"
WOWNERO_VERSION=v0.11.0.3
WOWNERO_SHA_HEAD="e921c3b8a35bc497ef92c4735e778e918b4c4f99"
WOWNERO_SRC_DIR="${EXTERNAL_MACOS_SOURCE_DIR}/wownero"
BUILD_TYPE=release
PREFIX=${EXTERNAL_MACOS_DIR}
DEST_LIB_DIR=${EXTERNAL_MACOS_LIB_DIR}/wownero
DEST_INCLUDE_DIR=${EXTERNAL_MACOS_INCLUDE_DIR}/wownero

echo "Cloning wownero from - $WOWNERO_URL to - $WOWNERO_SRC_DIR"
git clone ${WOWNERO_URL} ${WOWNERO_SRC_DIR} --branch ${WOWNERO_VERSION}
cd $WOWNERO_SRC_DIR
git reset --hard $WOWNERO_SHA_HEAD
git checkout $WOWNERO_VERSION
git submodule update --init --force
git apply --stat --apply ${CW_ROOT}/patches/wownero/refresh_thread.patch
mkdir -p build
cd ..

echo $DEST_LIB_DIR
mkdir -p $DEST_LIB_DIR
mkdir -p $DEST_INCLUDE_DIR

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z $INSTALL_PREFIX ]; then
    INSTALL_PREFIX=${ROOT_DIR}/wownero
fi

echo "Building MACOS ${arch}"
export CMAKE_INCLUDE_PATH="${PREFIX}/include"
export CMAKE_LIBRARY_PATH="${PREFIX}/lib"

if [ "${ARCH}" == "x86_64" ]; then
	ARCH="x86-64"
fi

rm -r wownero/build > /dev/null

mkdir -p wownero/build/${BUILD_TYPE}
pushd wownero/build/${BUILD_TYPE}
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