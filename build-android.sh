#!/bin/bash

# Cross-compilation script for Android (ARM64)
set -e

echo "Building luks-luau for Android (ARM64)..."

TARGET_ARCH="aarch64-linux-android"

# Step 1: Build luksruntime
echo "[1/3] Building luksruntime..."
cargo build -p luksruntime --release --target "$TARGET_ARCH"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build luksruntime"
    exit 1
fi

# Step 2: No rename needed for Android (.so is correct)
echo "[2/3] Library file ready (libluksruntime.so)"

# Step 3: Build lukscli
echo "[3/3] Building lukscli..."
cargo build -p lukscli --release --target "$TARGET_ARCH"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build lukscli"
    exit 1
fi

echo ""
echo "Build completed successfully!"
echo "Output:"
echo "  - libluksruntime.so: target/$TARGET_ARCH/release/libluksruntime.so"
echo "  - lukscli: target/$TARGET_ARCH/release/lukscli"
