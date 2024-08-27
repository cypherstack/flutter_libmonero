#!/bin/bash

set -x -e

cd "$(dirname "$0")"


# Allow script caller to pass commit hash.
# dirty hack to handle broken monero_c on android. Uses same hash on linux as well to make dev life easier
# CHASH="$1"
# if [ -z "$CHASH" ]; then
#   CHASH="294b593db30e8803586dfd0f47e716ce1200c766"
# fi

if [[ ! -d "monero_c" ]];
then
    git clone https://github.com/mrcyjanek/monero_c --branch rewrite-wip
    cd monero_c
    git checkout "294b593db30e8803586dfd0f47e716ce1200c766"
    git reset --hard
    git config submodule.libs/wownero.url https://git.cypherstack.com/Cypher_Stack/wownero
    git config submodule.libs/wownero-seed.url https://git.cypherstack.com/Cypher_Stack/wownero-seed
    git submodule update --init --force --recursive
    ./apply_patches.sh monero
    ./apply_patches.sh wownero
else
    cd monero_c
fi

if [[ ! -f "monero/.patch-applied" ]];
then
    ./apply_patches.sh monero
fi

if [[ ! -f "wownero/.patch-applied" ]];
then
    ./apply_patches.sh wownero
fi
cd ..


MONERO_C_HASH="$(cd monero_c && git log -1 --pretty=format:"%H")"

cat > ../lib/git_versions.dart <<EOF
import 'dart:io';

/*ANDROID_VERSION*/ const ANDROID_VERSION = "${MONERO_C_HASH}";
/*IOS_VERSION*/ const IOS_VERSION = "${MONERO_C_HASH}";
/*MACOS_VERSION*/ const MACOS_VERSION = "${MONERO_C_HASH}";
/*LINUX_VERSION*/ const LINUX_VERSION = "${MONERO_C_HASH}";
/*WINDOWS_VERSION*/ const WINDOWS_VERSION = "${MONERO_C_HASH}";

String getPluginVersion() {
  if (Platform.isAndroid) {
    return ANDROID_VERSION;
  } else if (Platform.isIOS) {
    return IOS_VERSION;
  } else if (Platform.isMacOS) {
    return MACOS_VERSION;
  } else if (Platform.isLinux) {
    return LINUX_VERSION;
  } else if (Platform.isWindows) {
    return WINDOWS_VERSION;
  } else {
    return "Unknown version";
  }
}
EOF

echo "monero_c source prepared"
