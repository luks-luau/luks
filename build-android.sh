#!/bin/bash

# Cross-compilation script for Android (ARM64)
set -e

echo "Building luks-luau for Android (ARM64)..."

TARGET_ARCH="aarch64-linux-android"

# Step 1: Build luksruntime
echo "[1/4] Building luksruntime..."
cargo build -p luksruntime --release --target "$TARGET_ARCH"

# Step 2: Runtime naming
echo "[2/4] Library file ready (libluksruntime.so)"

# Step 3: Build lukscli
echo "[3/4] Building lukscli..."
cargo build -p lukscli --release --target "$TARGET_ARCH"

# Step 4: Install binaries and ensure PATH (Termux-friendly)
echo "[4/4] Installing luks and runtime..."
RUNTIME_SRC="target/$TARGET_ARCH/release/libluksruntime.so"
CLI_SRC="target/$TARGET_ARCH/release/lukscli"

if [ -n "${PREFIX:-}" ]; then
    SYSTEM_BIN="$PREFIX/bin"
else
    SYSTEM_BIN="/data/data/com.termux/files/usr/bin"
fi
USER_BIN="$HOME/.local/bin"

INSTALL_BIN="$SYSTEM_BIN"
USE_FALLBACK=0

if ! mkdir -p "$INSTALL_BIN" 2>/dev/null; then
    USE_FALLBACK=1
fi

if [ "$USE_FALLBACK" -eq 0 ]; then
    if ! touch "$INSTALL_BIN/.luks_write_test" 2>/dev/null; then
        USE_FALLBACK=1
    else
        rm -f "$INSTALL_BIN/.luks_write_test"
    fi
fi

if [ "$USE_FALLBACK" -eq 1 ]; then
    echo "INFO: No permission for $SYSTEM_BIN. Falling back to $USER_BIN."
    INSTALL_BIN="$USER_BIN"
    mkdir -p "$INSTALL_BIN"
fi

cp "$CLI_SRC" "$INSTALL_BIN/luks"
cp "$RUNTIME_SRC" "$INSTALL_BIN/libluksruntime.so"
chmod +x "$INSTALL_BIN/luks"

HOT_BIN=""
OLD_IFS="$IFS"
IFS=":"
for path_dir in $PATH; do
    if [ -n "$path_dir" ] && [ -d "$path_dir" ] && [ -w "$path_dir" ] && [[ "$path_dir" == "$HOME"* ]]; then
        HOT_BIN="$path_dir"
        break
    fi
done
IFS="$OLD_IFS"

if [ -z "$HOT_BIN" ]; then
    HOT_BIN="$HOME/.local/bin"
    mkdir -p "$HOT_BIN"
fi

if [ "$HOT_BIN" != "$INSTALL_BIN" ]; then
    cat > "$HOT_BIN/luks" <<EOF
#!/bin/sh
exec "$INSTALL_BIN/luks" "\$@"
EOF
    chmod +x "$HOT_BIN/luks"
else
    if [ ! -x "$HOT_BIN/luks" ]; then
        chmod +x "$HOT_BIN/luks"
    fi
fi

if [[ ":$PATH:" != *":$INSTALL_BIN:"* ]]; then
    export PATH="$INSTALL_BIN:$PATH"
    echo "INFO: Added $INSTALL_BIN to current PATH."
fi

if [[ ":$PATH:" != *":$HOT_BIN:"* ]]; then
    export PATH="$HOT_BIN:$PATH"
    echo "INFO: Added $HOT_BIN to current PATH."
fi

for rc_file in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc_file" ] || [ "$rc_file" = "$HOME/.profile" ]; then
        if ! grep -Fqs "$INSTALL_BIN" "$rc_file" 2>/dev/null; then
            {
                printf "\n# Added by luks-luau Android build script\n"
                printf "export PATH=\"%s:\$PATH\"\n" "$INSTALL_BIN"
            } >> "$rc_file"
            echo "INFO: Added PATH entry to $rc_file"
        fi
        if ! grep -Fqs "$HOT_BIN" "$rc_file" 2>/dev/null; then
            {
                printf "\n# Added by luks-luau Android build script\n"
                printf "export PATH=\"%s:\$PATH\"\n" "$HOT_BIN"
            } >> "$rc_file"
            echo "INFO: Added PATH entry to $rc_file"
        fi
    fi
done

echo ""
echo "Build completed successfully!"
echo "Output:"
echo "  - libluksruntime.so: target/$TARGET_ARCH/release/libluksruntime.so"
echo "  - lukscli: target/$TARGET_ARCH/release/lukscli"
echo "Installed:"
echo "  - luks: $INSTALL_BIN/luks"
echo "  - libluksruntime.so: $INSTALL_BIN/libluksruntime.so"
echo "  - command shim: $HOT_BIN/luks"

if command -v luks >/dev/null 2>&1; then
    echo "Ready: \`luks\` is available in this shell."
else
    echo "INFO: This script runs in a subshell, so parent PATH cannot be changed automatically."
    echo "Run now in current terminal:"
    echo "  export PATH=\"$HOT_BIN:$INSTALL_BIN:\$PATH\" && hash -r"
fi
