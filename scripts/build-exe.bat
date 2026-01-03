@echo off
title Build ZugChain Deposit EXE
color 0b

echo Logging to build_log.txt...
(
    echo ==================================================
    echo   Building ZugChainDeposit.exe
    echo   Date: %date% %time%
    echo ==================================================
    echo.

    echo [INFO] Checking Python...
    python --version
    if %errorlevel% neq 0 (
        echo [ERROR] Python is not installed or not in PATH.
        goto :ERROR
    )

    echo [INFO] Installing PyInstaller and dependencies...
    python -m pip install pyinstaller mnemonic py_ecc eth-utils pycryptodome
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to install dependencies.
        goto :ERROR
    )

    echo [INFO] Building EXE...
    echo Running: python -m PyInstaller ...
    
    python -m PyInstaller --onefile --name "ZugChainDeposit" ^
    --collect-all mnemonic ^
    --collect-all py_ecc ^
    --collect-all eth_utils ^
    --collect-all eth_typing ^
    --collect-all eth_hash ^
    --hidden-import=Crypto ^
    --distpath "dist" --workpath "build" --specpath "." keygen.py
    
    if %errorlevel% neq 0 (
        echo [ERROR] PyInstaller failed.
        goto :ERROR
    )

    echo.
    if exist "dist\ZugChainDeposit.exe" (
        echo [SUCCESS] EXE created successfully!
        echo Location: dist\ZugChainDeposit.exe
    ) else (
        echo [ERROR] EXE file not found in dist folder.
        goto :ERROR
    )

    echo.
    echo Done.
    exit /b 0

) > build_log.txt 2>&1

:: If we got here, check the log (this part runs in the console)
type build_log.txt
echo.
echo ==================================================
echo   Build Finished. Check above for errors.
echo ==================================================
pause
exit /b 0

:ERROR
echo.
echo [FATAL ERROR] Build Failed.
echo --------------------------------------------------
echo Check build_log.txt for details.
pause
exit /b 1
