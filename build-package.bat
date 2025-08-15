@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ========================================
echo   VSCode-EmmyLua Extension Package Script
echo ========================================
echo.

REM Check PowerShell
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell not found, please install PowerShell
    pause
    exit /b 1
)

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js not found, please install Node.js first
    echo Download: https://nodejs.org/
    pause
    exit /b 1
)

REM Show platform options
echo Select target platform:
echo 1. Windows x64 (default)
echo 2. Windows ARM64
echo 3. Linux x64
echo 4. Linux ARM64
echo 5. macOS x64
echo 6. macOS ARM64
echo.
set /p choice="Enter option (1-6, default is 1): "

REM Set target platform
if "%choice%"=="" set choice=1
if "%choice%"=="1" set target=win32-x64
if "%choice%"=="2" set target=win32-arm64
if "%choice%"=="3" set target=linux-x64
if "%choice%"=="4" set target=linux-arm64
if "%choice%"=="5" set target=darwin-x64
if "%choice%"=="6" set target=darwin-arm64

if not defined target (
    echo [ERROR] Invalid option, using default win32-x64
    set target=win32-x64
)

echo.
echo [INFO] Target platform: %target%
echo [INFO] Starting package process...
echo.

REM Execute PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp0build-package.ps1" -Target %target%

if errorlevel 1 (
    echo.
    echo [ERROR] Package failed, please check error messages above
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Package completed!
echo Output directory: %~dp0dist
echo.
echo Press any key to exit...
pause >nul