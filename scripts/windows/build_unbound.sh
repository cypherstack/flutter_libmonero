#!/bin/bash
. ./config.sh

./build_expat.sh
: '
UNBOUND_VERSION=release-1.15.0
UNBOUND_HASH="c29b0e0a96c4d281aef40d69a11c564d6ed1a2c6"
UNBOUND_SRC_DIR=$WORKDIR/unbound-1.15.0

UNBOUND_VERSION=release-1.16.2
UNBOUND_HASH="cbed768b8ff9bfcf11089a5f1699b7e5707f1ea5"
UNBOUND_SRC_DIR=$WORKDIR/unbound-1.16.2

UNBOUND_VERSION=release-1.17.0
UNBOUND_HASH="d25e0cd9b0545ff13120430c94326ceaf14b074f"
UNBOUND_SRC_DIR=$WORKDIR/unbound-1.17.0

UNBOUND_VERSION=release-1.17.1
UNBOUND_HASH="90831af981221bbce1cd7b15055562336760e484"
UNBOUND_SRC_DIR=$WORKDIR/unbound-1.17.1
'
UNBOUND_VERSION=master
UNBOUND_HASH="90831af981221bbce1cd7b15055562336760e484"
UNBOUND_SRC_DIR=$WORKDIR/unbound-1.17.1

cd $WORKDIR
if [[ ! -d $UNBOUND_SRC_DIR ]]; then
	git clone https://github.com/NLnetLabs/unbound ${UNBOUND_SRC_DIR} --branch ${UNBOUND_VERSION}
fi
cd $UNBOUND_SRC_DIR
git reset --hard origin/$UNBOUND_VERSION
if [[ -v UNBOUND_HASH ]]; then
	git reset --hard $UNBOUND_HASH
fi
test `git rev-parse HEAD` = ${UNBOUND_HASH} || exit 1

CC=x86_64-w64-mingw32.static-gcc
CXX=x86_64-w64-mingw32.static-g++
HOST=x86_64-w64-mingw32.static
./configure \
	CFLAGS=-fPIC \
	CXXFLAGS=-fPIC \
	--prefix=${PREFIX} \
	--host=${HOST} \
	--target=${HOST} \
	--enable-static \
	--disable-shared \
	--disable-flto \
	--enable-static-openssl \
	--with-openssl-includes=${PREFIX} \
	--with-pic \
	--with-ssl=${PREFIX} \
	--with-libexpat=${PREFIX} \
  LDFLAGS="-liphlpapi -lrpcrt4"
make -j$THREADS
make -j$THREADS install
