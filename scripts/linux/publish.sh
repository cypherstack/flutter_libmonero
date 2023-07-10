#!/bin/bash

. ./config.sh

OS=linux
TAG_COMMIT=$(git log -1 --pretty=format:"%H")

rm -rf flutter_libmonero_bins
git clone https://git.cypherstack.com/stackwallet/flutter_libmonero_bins
if [ -d flutter_libmonero_bins ]; then
  cd flutter_libmonero_bins
else
  echo "Failed to clone flutter_libmonero_bins"
  exit 1
fi

MONERO_BIN=libcw_monero.so
TARGET_PATH=../build
TARGET=$TYPES_OF_BUILD

if [ $(git tag -l "${OS}_${TARGET}_${TAG_COMMIT}") ]; then
  echo "Tag ${OS}_${TARGET}_${TAG_COMMIT} already exists!"
else
  ARCH_PATH=$TARGET

  if [ -f "$TARGET_PATH/$MONERO_BIN" ]; then
    git checkout "${OS}_${TARGET}_${TAG_COMMIT}" || git checkout -b "${OS}_${TARGET}_${TAG_COMMIT}"
    if [ ! -d "$OS/$ARCH_PATH" ]; then
      mkdir -p "$OS/$ARCH_PATH"
    fi
    cp -rf "$TARGET_PATH/$MONERO_BIN" "$OS/$ARCH_PATH/$MONERO_BIN"
    git add .
      git push origin $OS/$TARGET
    git push origin $OS/$TARGET
    git tag "${OS}_${TARGET}_${TAG_COMMIT}"
    git push --tags
  else
    echo "$TARGET not found!"
  fi
fi
