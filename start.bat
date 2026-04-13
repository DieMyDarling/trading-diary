@echo off
chcp 65001 >nul 2>&1
title Trading Journal
setlocal enabledelayedexpansion

echo ========================================
echo   TRADING JOURNAL
echo ========================================
echo.

REM ========================================
REM 1. CHECK PYTHON
REM ========================================
echo [1/5] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found!
    echo.
    echo Please install Python from: https://www.python.org/downloads/
    echo IMPORTANT: Check "Add Python to PATH" during installation
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version 2^>^&1') do set PYTHON_VER=%%i
echo [OK] %PYTHON_VER%
echo.

REM ========================================
REM 2. CREATE VIRTUAL ENVIRONMENT
REM ========================================
echo [2/5] Setting up virtual environment...
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment
        pause
        exit /b 1
    )
    echo [OK] Virtual environment created
) else (
    echo [OK] Virtual environment already exists
)
echo.

REM ========================================
REM 3. ACTIVATE VENV AND INSTALL DEPENDENCIES
REM ========================================
echo [3/5] Installing dependencies...
call venv\Scripts\activate.bat >nul 2>&1

pip install --upgrade pip -q
pip install flask flask-cors MetaTrader5 -q
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM ========================================
REM 4. LOAD TRADES FROM MT5
REM ========================================
echo [4/5] Loading trades from MetaTrader 5...
echo.

REM Check if trades.json exists and ask for reload
if exist "trades.json" (
    echo ⚠️  trades.json already exists
    echo.
    echo Options:
    echo   [1] Use existing data (quick start)
    echo   [2] Reload from MetaTrader 5
    echo.
    choice /c 12 /n /m "Choose (1 or 2): "
    if "!errorlevel!"=="2" (
        echo.
        echo Loading fresh data from MT5...
        del trades.json >nul 2>&1
        python mt5_loader.py
        if errorlevel 1 (
            echo.
            echo [ERROR] Failed to load from MT5!
            echo.
            echo Possible reasons:
            echo   - MetaTrader 5 not running
            echo   - Not logged in
            echo   - No closed positions
            echo.
            echo You can still use existing data if available.
            echo.
            if exist "trades.json" (
                echo Using existing trades.json
            ) else (
                echo [ERROR] No trades data available!
                pause
                exit /b 1
            )
        ) else (
            echo [OK] Fresh data loaded
        )
    ) else (
        echo [OK] Using existing trades.json
    )
) else (
    echo Loading trades from MetaTrader 5...
    echo.
    echo ========================================
    echo   IMPORTANT!
    echo   Make sure MetaTrader 5 is RUNNING
    echo   and you are LOGGED IN
    echo ========================================
    echo.
    
    python mt5_loader.py
    if errorlevel 1 (
        echo.
        echo [ERROR] Failed to load trades from MT5!
        echo.
        echo Please check:
        echo   1. MetaTrader 5 is running
        echo   2. You are logged in
        echo   3. You have closed positions
        echo.
        echo Press any key to exit...
        pause >nul
        exit /b 1
    )
    echo [OK] Trades loaded successfully
)
echo.

REM ========================================
REM 5. START WEB SERVER
REM ========================================
echo [5/5] Starting web server...
echo.
echo ========================================
echo   ✅ Ready!
echo   🌐 Open: http://localhost:5000
echo   ⏹️  Press Ctrl+C to stop
echo ========================================
echo.

python app.py

echo.
echo Server stopped
pause