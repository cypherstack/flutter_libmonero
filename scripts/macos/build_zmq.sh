#!/bin/sh

. ./config.sh

ZMQ_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/libzmq"
ZMQ_URL="https://github.com/zeromq/libzmq.git"

echo "============================ ZMQ ============================"

echo "Cloning ZMQ from - $ZMQ_URL"
git clone $ZMQ_URL $ZMQ_PATH
cd $ZMQ_PATH
mkdir cmake-build
cd cmake-build
export MACOSX_DEPLOYMENT_TARGET=11.0
cmake .. -DCMAKE_INSTALL_PREFIX="${EXTERNAL_MACOS_DIR}" -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_MIN_VERSION=11.0
make
make install
