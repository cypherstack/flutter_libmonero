#!/bin/bash

# IOS scripts WIP; doublecheck that they follow patterns in linux/android scripts before running

LIB_ROOT=../..
OS=ios
IOS_LIBS_DIR=$LIB_ROOT/$OS/libs
IOS_INCL_DIR=$LIB_ROOT/$OS/include

TAG_COMMIT=$(git log -1 --pretty=format:"%H")

rm -rf flutter_libmonero_bins
git clone https://git.cypherstack.com/stackwallet/flutter_libmonero_bins
if [ -d flutter_libmonero_bins ]; then
  cd flutter_libmonero_bins
else
  echo "Failed to clone flutter_libmonero_bins"
  exit 1
fi

MONERO_HEADER=libcw_monero.h
MONERO_BIN=libcw_monero.a

for TARGET in aarch64-apple-ios
do
  ARCH_PATH=$TARGET/release
  if [ $(git tag -l $TARGET"_$TAG_COMMIT") ]; then
      git checkout "${OS}_${TARGET}_${TAG_COMMIT}"
      mkdir -p ../$IOS_LIBS_DIR
      mkdir -p ../$IOS_INCL_DIR
      if [ -f "$OS/$ARCH_PATH/$MONERO_BIN" ]; then
        # TODO verify bin checksum hashes
        cp -rf "$OS/$ARCH_PATH/$MONERO_BIN" "../$IOS_LIBS_DIR/$MONERO_BIN"
        cp -rf "$OS/$ARCH_PATH/$MONERO_HEADER" "../$IOS_INCL_DIR/$MONERO_HEADER"
      else
        echo "$TARGET not found!"
      fi
  else
      echo "No precompiled bins for $TARGET found!"
  fi
done
