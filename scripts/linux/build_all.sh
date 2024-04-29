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
OS="LINUX"
sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE

# Build monero_c.
cd "$(dirname "$0")"

if [[ ! "x$(uname)" == "xLinux" ]];
then
    echo "Only Linux hosts can build linux";
    exit 1
fi

../prepare_moneroc.sh
pushd ../monero_c
    ./build_single.sh monero x86_64-linux-gnu -j8
    ./build_single.sh wownero x86_64-linux-gnu -j8
popd

unxz -f ../monero_c/release/monero/x86_64-linux-gnu_libwallet2_api_c.dylib.xz
unxz -f ../monero_c/release/wownero/x86_64-linux-gnu_libwallet2_api_c.dylib.xz
