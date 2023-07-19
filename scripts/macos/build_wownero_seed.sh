#!/bin/sh

. ./config.sh

SEED_VERSION=0.3.0
SEED_SRC_DIR="${EXTERNAL_MACOS_SOURCE_DIR}/seed"
SEED_URL="https://git.wownero.com/wowlet/wownero-seed.git"
SEED_SHA_HEAD="ef6910b6bb3b61757c36e2e5db0927d75f1731c8"

rm -rf "$SEED_SRC_DIR" > /dev/null

echo "[*] cloning $SEED_URL"
git clone --branch ${SEED_VERSION} ${SEED_URL} ${SEED_SRC_DIR}
cd $SEED_SRC_DIR
git reset --hard $SEED_SHA_HEAD

BUILD_TYPE=release
PREFIX=${EXTERNAL_MACOS_DIR}
DEST_LIB_DIR=${EXTERNAL_MACOS_LIB_DIR}/wownero-seed
DEST_INCLUDE_DIR=${EXTERNAL_MACOS_INCLUDE_DIR}/wownero-seed

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z $INSTALL_PREFIX ]; then
    INSTALL_PREFIX=${ROOT_DIR}/wownero-seed
fi

for arch in "arm64" #"armv7" "arm64"
do

echo "Building wownero-seed MACOS ${arch}"
export CMAKE_INCLUDE_PATH="${PREFIX}/include"
export CMAKE_LIBRARY_PATH="${PREFIX}/lib"

if [ "${ARCH}" == "x86_64" ]; then
	ARCH="x86-64"
fi

#cmake -Bbuild -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCMAKE_SYSTEM_NAME="OSX" -DCMAKE_OSX_ARCHITECTURES="${arch}" .
cmake -Bbuild -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_MIN_VERSION=11.0 .
make -Cbuild -j$(nproc)
make -Cbuild install
cp $CMAKE_LIBRARY_PATH/libwownero-seed.a $CMAKE_LIBRARY_PATH/wownero/libwownero-seed.a

done
