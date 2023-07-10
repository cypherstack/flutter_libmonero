#!/bin/bash

# IOS scripts WIP; doublecheck that they follow patterns in linux/android scripts before running

OS=ios
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
MONERO_BIN=libcw_monero.so
TARGET_PATH=../build

for TARGET in aarch64-apple-ios x86_64-apple-ios
do
  if [ $(git tag -l "${TARGET}_${TAG_COMMIT}") ]; then
    echo "Tag ${TARGET}_${TAG_COMMIT} already exists!"
  else
    ARCH_PATH=$TARGET/release

    if [ -f "$TARGET_PATH/$MONERO_BIN" ]; then
      git checkout "${OS}_${TARGET}_${TAG_COMMIT}" || git checkout -b "${OS}_${TARGET}_${TAG_COMMIT}"
      if [ ! -d $OS/$ARCH_PATH ]; then
        mkdir -p $OS/$ARCH_PATH
      fi
      cp -rf $TARGET_PATH/$ARCH_PATH/$MONERO_BIN $OS/$ARCH_PATH/$MONERO_BIN
      cp -rf $TARGET_PATH/../$MONERO_HEADER $OS/$ARCH_PATH/$MONERO_HEADER
      git add .
      git commit -m "$TARGET commit for $TAG_COMMIT"
      git push origin "${OS}_${TARGET}_${TAG_COMMIT}"
      git tag "${OS}_${TARGET}_${TAG_COMMIT}"
      git push --tags
    else
      echo "$TARGET not found!"
    fi
  fi
done
