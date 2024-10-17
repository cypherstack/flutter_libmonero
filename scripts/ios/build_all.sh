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

 # ==================== Monero ======================================================================
 FRAMEWORK_NAME="MoneroWallet"
 DYLIB_PATH=$(realpath "../monero_c/release/monero/host-apple-ios_libwallet2_api_c.dylib")
 ./gen_fw.sh ${FRAMEWORK_NAME} ${DYLIB_PATH}
 echo "Framework created at ${OUTPUT_DIR}/${FRAMEWORK_NAME}.framework"


 # ==================== Wownero =====================================================================
 FRAMEWORK_NAME="WowneroWallet"
 DYLIB_PATH=$(realpath "../monero_c/release/wownero/host-apple-ios_libwallet2_api_c.dylib")
 ./gen_fw.sh ${FRAMEWORK_NAME} ${DYLIB_PATH}
 echo "Framework created at ${OUTPUT_DIR}/${FRAMEWORK_NAME}.framework"

