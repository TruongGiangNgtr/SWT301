@echo off
setlocal
title SWT301 - Test Workspace
set "SWT_PWSH="
for /f "delims=" %%I in ('where pwsh.exe 2^>nul') do if not defined SWT_PWSH set "SWT_PWSH=%%I"
if not defined SWT_PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "SWT_PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined SWT_PWSH if exist "%~dp0..\tools-swt301\powershell\pwsh.exe" set "SWT_PWSH=%~dp0..\tools-swt301\powershell\pwsh.exe"
if not defined SWT_PWSH (
    echo PowerShell 7 is required. Install it or load your local environment.
    pause
    exit /b 1
)
"%SWT_PWSH%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0ci\start-dashboard.ps1" %*
if errorlevel 1 pause
endlocal
