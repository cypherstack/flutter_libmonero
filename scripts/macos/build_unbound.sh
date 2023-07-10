#!/bin/sh

. ./config.sh

UNBOUND_VERSION=1.13.2
UNBOUND_HASH=0a13b547f3b92a026b5ebd0423f54c991e5718037fd9f72445817f6a040e1a83
UNBOUND_URL="https://www.nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz"
UNBOUND_DIR_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/unbound-${UNBOUND_VERSION}"
UNBOUND_ARCH_PATH=${EXTERNAL_MACOS_SOURCE_DIR}/unbound-${UNBOUND_VERSION}.tar.gz

echo $UNBOUND_DIR_PATH
echo "============================ Unbound ============================"
curl $UNBOUND_URL -L -o $UNBOUND_ARCH_PATH
tar -xzf $UNBOUND_ARCH_PATH -C $EXTERNAL_MACOS_SOURCE_DIR
cd $UNBOUND_DIR_PATH
#rm -rf ${UNBOUND_DIR_PATH}
#git clone https://github.com/NLnetLabs/unbound.git -b ${UNBOUND_VERSION} ${UNBOUND_DIR_PATH}
#cd $UNBOUND_DIR_PATH
#test `git rev-parse HEAD` = ${UNBOUND_HASH} || exit 1

./configure --prefix="${EXTERNAL_MACOS_DIR}" \
			--with-ssl="${EXTERNAL_MACOS_DIR}" \
			--with-libexpat="${EXTERNAL_MACOS_DIR}" \
			--enable-static \
			--disable-shared \
			--disable-flto
make
make install