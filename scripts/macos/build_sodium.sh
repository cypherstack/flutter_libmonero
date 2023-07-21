#!/bin/sh

. ./config.sh

SODIUM_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/libsodium"
SODIUM_URL="https://github.com/jedisct1/libsodium.git"

echo "============================ SODIUM ============================"

echo "Cloning SODIUM from - $SODIUM_URL"
git clone $SODIUM_URL $SODIUM_PATH --branch stable
cd $SODIUM_PATH

export PREFIX="$(pwd)/../../"
export MACOS_VERSION_MIN=${MACOS_VERSION_MIN-"10.10"}

if [ -z "$LIBSODIUM_FULL_BUILD" ]; then
  export LIBSODIUM_ENABLE_MINIMAL_FLAG="--enable-minimal"
else
  export LIBSODIUM_ENABLE_MINIMAL_FLAG=""
fi

NPROCESSORS=$(getconf NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)
PROCESSORS=${NPROCESSORS:-3}
export CFLAGS="-mmacosx-version-min=${MACOS_VERSION_MIN} -O2 -g"
export LDFLAGS="-mmacosx-version-min=${MACOS_VERSION_MIN}"

./configure ${LIBSODIUM_ENABLE_MINIMAL_FLAG} \
  --prefix="$PREFIX" || exit 1
make -j${PROCESSORS} check && make -j${PROCESSORS} install || exit 1

