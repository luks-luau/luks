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
    move /Y "target\release\luksruntime.dll.lib" "target\release\luksruntime.lib"
    if !errorlevel! neq 0 (
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

REM Define os diretórios de instalação. A expansão atrasada (!VAR!) evita problemas com parênteses.
if defined ProgramFiles(x86) (
    set "SYSTEM_BIN=%ProgramFiles(x86)%\Luks\bin"
) else (
    set "SYSTEM_BIN=%ProgramFiles%\Luks\bin"
)
set "USER_BIN=%LOCALAPPDATA%\Luks\bin"

REM Usamos !SYSTEM_BIN! para o restante do script. %SYSTEM_BIN% só é usado dentro do bloco if acima, 
REM que não causa erro pois a expansão é imediata e não há parênteses problemáticos.
set "INSTALL_BIN=!SYSTEM_BIN!"
set "LUKS_SYSTEM_BIN=!SYSTEM_BIN!"

REM Criação do diretório: o if not exist está fora de qualquer bloco,
REM e usamos !INSTALL_BIN! com expansão atrasada.
if not exist "!INSTALL_BIN!" mkdir "!INSTALL_BIN!" >nul 2>&1

copy /Y "target\release\lukscli.exe" "!INSTALL_BIN!\luks.exe" >nul 2>&1
if !errorlevel! neq 0 (
    echo INFO: Admin permission required to install into "!INSTALL_BIN!".
    echo INFO: Requesting elevation only for copy step...
    
    REM O script elevado agora é gerado com os caminhos salvos em variáveis de ambiente,
    REM que não são expandidas diretamente pelo cmd.exe, eliminando o erro.
    set "ELEVATED_PS=%TEMP%\luks_install_elevated.ps1"
    set "LUKS_ELEVATED_DST=!INSTALL_BIN!"
    set "LUKS_ELEVATED_SRC=!CD!\target\release"

    REM A geração do script .ps1 usa apenas eco simples, sem blocos parênteses problemáticos.
    (
        echo $dst = $env:LUKS_ELEVATED_DST
        echo $srcDir = $env:LUKS_ELEVATED_SRC
        echo New-Item -ItemType Directory -Force -Path $dst ^| Out-Null
        echo Copy-Item -LiteralPath "$srcDir\lukscli.exe" -Destination "$dst\luks.exe" -Force
        echo Copy-Item -LiteralPath "$srcDir\luksruntime.dll" -Destination "$dst\luksruntime.dll" -Force
    ) > "!ELEVATED_PS!"

    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""!ELEVATED_PS!""' -Verb RunAs -Wait -WindowStyle Hidden"
    set "ELEVATE_EXIT=!errorlevel!"
    del "!ELEVATED_PS!" >nul 2>&1

    if !ELEVATE_EXIT! neq 0 (
        echo INFO: Elevation declined or failed. Falling back to "!USER_BIN!".
        set "INSTALL_BIN=!USER_BIN!"
        if not exist "!INSTALL_BIN!" mkdir "!INSTALL_BIN!" >nul 2>&1

        copy /Y "target\release\lukscli.exe" "!INSTALL_BIN!\luks.exe" >nul
        if !errorlevel! neq 0 (
            echo ERROR: Failed to copy luks.exe to "!INSTALL_BIN!"
            exit /b 1
        )

        copy /Y "target\release\luksruntime.dll" "!INSTALL_BIN!\luksruntime.dll" >nul
        if !errorlevel! neq 0 (
            echo ERROR: Failed to copy luksruntime.dll to "!INSTALL_BIN!"
            exit /b 1
        )
    )
) else (
    copy /Y "target\release\luksruntime.dll" "!INSTALL_BIN!\luksruntime.dll" >nul
    if !errorlevel! neq 0 (
        echo ERROR: Failed to copy luksruntime.dll to "!INSTALL_BIN!"
        exit /b 1
    )
)

REM As linhas de verificação do PATH também usam !INSTALL_BIN!.
set "CURRENT_PATH=;%PATH%;"
echo !CURRENT_PATH! | findstr /I /C:";!INSTALL_BIN!;" >nul
if !errorlevel! neq 0 (
    setx PATH "%PATH%;!INSTALL_BIN!" >nul
    if !errorlevel! neq 0 (
        echo WARNING: Failed to persist PATH update. Add manually: !INSTALL_BIN!
    ) else (
        set "PATH=%PATH%;!INSTALL_BIN!"
        echo INFO: Added "!INSTALL_BIN!" to PATH.
    )
) else (
    echo INFO: PATH already contains "!INSTALL_BIN!".
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