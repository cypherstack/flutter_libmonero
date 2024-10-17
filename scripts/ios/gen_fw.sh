#!/usr/bin/env bash
set -x -e

#
# Build frameworks for ios
#

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <framework_name> <dylib>"
  exit 1
fi

FRAMEWORK_NAME=$1
DYLIB_PATH=$2
IOS_DIR=$(realpath "../../ios")
IOS_DIR_FRAMEWORKS="${IOS_DIR}/Frameworks"

echo $IOS_DIR_FRAMEWORKS

mkdir -p "${IOS_DIR_FRAMEWORKS}/${FRAMEWORK_NAME}.framework"

pushd "${IOS_DIR_FRAMEWORKS}/${FRAMEWORK_NAME}.framework"
  lipo -create ${DYLIB_PATH} -output ${FRAMEWORK_NAME}
  install_name_tool -id "@rpath/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" ${FRAMEWORK_NAME}
popd

# create info.plist
PLIST_FILE="${IOS_DIR_FRAMEWORKS}/${FRAMEWORK_NAME}.framework/Info.plist"

cat << EOF > "${PLIST_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.${FRAMEWORK_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>0.0.1</string>
</dict>
</plist>

EOF