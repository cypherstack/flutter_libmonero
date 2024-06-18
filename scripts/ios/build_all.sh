#!/bin/sh

set -x -e

# Format git_versions.dart.
# echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> ../monero_c/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="IOS"
sed -i '' "s/const ${OS}_VERSION = .*/const ${OS}_VERSION = \"$COMMIT\";/g" $VERSIONS_FILE

cd "$(dirname "$0")"

if [[ ! "x$(uname)" == "xDarwin" ]];
then
    echo "Only Darwin hosts can build ios";
    exit 1
fi

../prepare_moneroc.sh
pushd ../monero_c
    rm -rf external/ios/build
    ./build_single.sh monero host-apple-ios -j8
    rm -rf external/ios/build
    ./build_single.sh wownero host-apple-ios -j8
popd

unxz -f ../monero_c/release/monero/host-apple-ios_libwallet2_api_c.dylib.xz
unxz -f ../monero_c/release/wownero/host-apple-ios_libwallet2_api_c.dylib.xz

ln -s $(realpath ../monero_c/release/monero/host-apple-ios_libwallet2_api_c.dylib) ../../../../ios/monero_libwallet2_api_c.dylib || true
ln -s $(realpath ../monero_c/release/wownero/host-apple-ios_libwallet2_api_c.dylib) ../../../../ios/wownero_libwallet2_api_c.dylib || true

IOS_DIR="../../../../ios/"
DYLIB_NAME="monero_libwallet2_api_c.dylib"
DYLIB_LINK_PATH=$(realpath "../monero_c/release/monero/host-apple-ios_libwallet2_api_c.dylib")
FRWK_DIR="${IOS_DIR}/MoneroWallet.framework"

if [ ! -f $DYLIB_LINK_PATH ]; then
    echo "Dylib is not found by the link: ${DYLIB_LINK_PATH}"
    exit 0
fi

pushd $FRWK_DIR # go to iOS framework dir
    lipo -create $DYLIB_LINK_PATH -output MoneroWallet
popd
echo "Generated ${FRWK_DIR}"


IOS_DIR="../../../../ios/"
DYLIB_NAME="wownero_libwallet2_api_c.dylib"
DYLIB_LINK_PATH=$(realpath "../monero_c/release/wownero/host-apple-ios_libwallet2_api_c.dylib")
FRWK_DIR="${IOS_DIR}/WowneroWallet.framework"

if [ ! -f $DYLIB_LINK_PATH ]; then
    echo "Dylib is not found by the link: ${DYLIB_LINK_PATH}"
    exit 0
fi

pushd $FRWK_DIR # go to iOS framework dir
    lipo -create $DYLIB_LINK_PATH -output WowneroWallet
popd

echo "Generated ${FRWK_DIR}"

