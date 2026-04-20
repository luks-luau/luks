#!/bin/bash

echo "Building luks-luau for Unix (Linux/macOS)..."

# Step 1: Build luksruntime
echo "[1/3] Building luksruntime..."
cargo build -p luksruntime --release
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build luksruntime"
    exit 1
fi

# Step 2: On Unix, the library is named differently
# On Linux: luksruntime.so
# On macOS: luksruntime.dylib
# No renaming needed for Unix platforms
echo "[2/3] Library file ready (no rename needed on Unix)"

# Step 3: Build lukscli
echo "[3/3] Building lukscli..."
cargo build -p lukscli --release
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build lukscli"
    exit 1
fi

echo ""
echo "Build completed successfully!"
echo "Output:"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "  - luksruntime.so: target/release/libluksruntime.so"
    echo "  - lukscli: target/release/lukscli"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  - luksruntime.dylib: target/release/libluksruntime.dylib"
    echo "  - lukscli: target/release/lukscli"
fi
