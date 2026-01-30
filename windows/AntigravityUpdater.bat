@echo off
chcp 65001 >nul 2>&1
title Antigravity Tools Updater

:: Check for PowerShell
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo PowerShell is required to run this application.
    echo Please install PowerShell and try again.
    pause
    exit /b 1
)

:: Get script directory
set "SCRIPT_DIR=%~dp0"

:: Run PowerShell script with execution policy bypass
powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%antigravity-update.ps1" %*

exit /b %errorlevel%
