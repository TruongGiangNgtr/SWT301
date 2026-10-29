@echo off
setlocal
set "SWT_PWSH=pwsh.exe"
where pwsh.exe >nul 2>&1
if not errorlevel 1 goto launch
set "SWT_PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if exist "%SWT_PWSH%" goto launch
set "SWT_PWSH=%~dp0..\tools-swt301\powershell\pwsh.exe"
if exist "%SWT_PWSH%" goto launch
echo PowerShell 7 was not found. Install PowerShell 7 or add pwsh.exe to PATH.
echo No software has been installed automatically.
pause
exit /b 1

:launch
rem Trust only the test helper scripts shipped with this project (downloaded ZIPs
rem can mark them as Internet files). Keep RemoteSigned and system policy intact.
set "SWT_RUNNER_ROOT=%~dp0"
"%SWT_PWSH%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command "$ErrorActionPreference = 'Stop'; foreach ($relative in @('ci', 'tests/performance', 'tests/visual')) { Get-ChildItem -LiteralPath (Join-Path $env:SWT_RUNNER_ROOT $relative) -File | Where-Object { $_.Extension -in '.ps1', '.psm1' } | Unblock-File -ErrorAction Stop }"
if errorlevel 1 goto runner-finished
"%SWT_PWSH%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0ci\test-menu.ps1" %*
:runner-finished
set "SWT_EXIT=%ERRORLEVEL%"
if not "%SWT_EXIT%"=="0" (
  echo.
  echo The runner returned exit code %SWT_EXIT%. Review the output above.
  pause
)
exit /b %SWT_EXIT%
