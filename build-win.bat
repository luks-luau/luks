@echo off
echo Building luks-luau for Windows...

REM Step 1: Build luksruntime
echo [1/3] Building luksruntime...
cargo build -p luksruntime --release
if %errorlevel% neq 0 (
    echo ERROR: Failed to build luksruntime
    exit /b 1
)

REM Step 2: Rename luksruntime.dll.lib to luksruntime.lib
echo [2/3] Renaming luksruntime.dll.lib to luksruntime.lib...
if exist "target\release\luksruntime.dll.lib" (
    ren "target\release\luksruntime.dll.lib" "luksruntime.lib"
    if %errorlevel% neq 0 (
        echo ERROR: Failed to rename library file
        exit /b 1
    )
) else (
    echo ERROR: luksruntime.dll.lib not found in target\release
    exit /b 1
)

REM Step 3: Build lukscli
echo [3/3] Building lukscli...
cargo build -p lukscli --release
if %errorlevel% neq 0 (
    echo ERROR: Failed to build lukscli
    exit /b 1
)

echo.
echo Build completed successfully!
echo Output:
echo   - luksruntime.dll: target\release\luksruntime.dll
echo   - luksruntime.lib: target\release\luksruntime.lib
echo   - lukscli.exe: target\release\lukscli.exe
