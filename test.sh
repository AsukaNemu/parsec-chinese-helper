#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
TEST_BINARY="$PROJECT_DIR/build/ConfigStoreTests"
mkdir -p "$PROJECT_DIR/build"

xcrun swiftc \
    -O \
    -swift-version 5 \
    -parse-as-library \
    -DTESTING \
    -target arm64-apple-macos13.0 \
    -framework AppKit \
    -framework SwiftUI \
    "$PROJECT_DIR/Sources/ParsecChineseHelper.swift" \
    "$PROJECT_DIR/Tests/ConfigStoreTests.swift" \
    -o "$TEST_BINARY"

"$TEST_BINARY"
