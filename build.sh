#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/build"
TARGET_ARCH="$(uname -m)"
APP_DIR="$BUILD_DIR/Parsec 中文助手.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/ParsecChinese.iconset"

if [[ "$BUILD_DIR" != "$PROJECT_DIR/build" ]]; then
    print -u2 "构建目录校验失败"
    exit 1
fi

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

xcrun swiftc \
    -O \
    -swift-version 5 \
    -parse-as-library \
    -target "$TARGET_ARCH-apple-macos13.0" \
    -framework AppKit \
    -framework SwiftUI \
    "$PROJECT_DIR/Sources/ParsecChineseHelper.swift" \
    -o "$MACOS_DIR/ParsecChineseHelper"

xcrun swiftc \
    -O \
    -swift-version 5 \
    -target "$TARGET_ARCH-apple-macos13.0" \
    -framework AppKit \
    "$PROJECT_DIR/Sources/IconGenerator.swift" \
    -o "$BUILD_DIR/IconGenerator"

"$BUILD_DIR/IconGenerator" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/ParsecChinese.icns"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --verify --deep --strict "$APP_DIR"

print "$APP_DIR"
