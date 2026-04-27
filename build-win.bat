@echo off
setlocal EnableExtensions EnableDelayedExpansion
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

REM Step 4: Install binaries and ensure PATH
echo [4/4] Installing luks to system path...
if defined ProgramFiles(x86) (
    set "SYSTEM_BIN=%ProgramFiles(x86)%\Luks\bin"
) else (
    set "SYSTEM_BIN=%ProgramFiles%\Luks\bin"
)
set "USER_BIN=%LOCALAPPDATA%\Luks\bin"
set "INSTALL_BIN=%SYSTEM_BIN%"
set "USE_FALLBACK=0"

if not exist "%INSTALL_BIN%" (
    mkdir "%INSTALL_BIN%" >nul 2>&1
    if !errorlevel! neq 0 set "USE_FALLBACK=1"
)

if "!USE_FALLBACK!"=="0" (
    > "%INSTALL_BIN%\.__luks_write_test.tmp" echo test 2>nul
    if !errorlevel! neq 0 (
        set "USE_FALLBACK=1"
    ) else (
        del "%INSTALL_BIN%\.__luks_write_test.tmp" >nul 2>&1
    )
)

if "!USE_FALLBACK!"=="1" (
    echo INFO: No permission for "%SYSTEM_BIN%". Falling back to "%USER_BIN%".
    set "INSTALL_BIN=%USER_BIN%"
    if not exist "%INSTALL_BIN%" (
        mkdir "%INSTALL_BIN%" >nul 2>&1
        if !errorlevel! neq 0 (
            echo ERROR: Failed to create fallback directory "%INSTALL_BIN%"
            exit /b 1
        )
    )
)

copy /Y "target\release\lukscli.exe" "%INSTALL_BIN%\luks.exe" >nul
if !errorlevel! neq 0 (
    echo ERROR: Failed to copy luks.exe to "%INSTALL_BIN%"
    exit /b 1
)

copy /Y "target\release\luksruntime.dll" "%INSTALL_BIN%\luksruntime.dll" >nul
if !errorlevel! neq 0 (
    echo ERROR: Failed to copy luksruntime.dll to "%INSTALL_BIN%"
    exit /b 1
)

set "CURRENT_PATH=;%PATH%;"
echo !CURRENT_PATH! | findstr /I /C:";%INSTALL_BIN%;" >nul
if !errorlevel! neq 0 (
    setx PATH "%PATH%;%INSTALL_BIN%" >nul
    if !errorlevel! neq 0 (
        echo WARNING: Failed to persist PATH update. Add manually: %INSTALL_BIN%
    ) else (
        set "PATH=%PATH%;%INSTALL_BIN%"
        echo INFO: Added "%INSTALL_BIN%" to PATH.
    )
) else (
    echo INFO: PATH already contains "%INSTALL_BIN%".
)

echo.
echo Build completed successfully!
echo Output:
echo   - luksruntime.dll: target\release\luksruntime.dll
echo   - luksruntime.lib: target\release\luksruntime.lib
echo   - lukscli.exe: target\release\lukscli.exe
echo Installed:
echo   - luks.exe: %INSTALL_BIN%\luks.exe
echo   - luksruntime.dll: %INSTALL_BIN%\luksruntime.dll
