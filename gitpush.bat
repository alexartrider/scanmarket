@echo off
setlocal enabledelayedexpansion
rem ============================================================
rem  ScanMarket: Git commit + push helper
rem  Usage:
rem    gitpush.bat                     -> commit with default message
rem    gitpush.bat "commit message"    -> commit with your message
rem  Private data (private_data\, bin\log\, log\) is ignored via .gitignore.
rem ============================================================

set "MSG=%~1"
if "%MSG%"=="" set "MSG=ScanMarket: update"

cd /d "%~dp0"

echo [1/4] git add -A ...
git add -A
if errorlevel 1 (
    echo ERROR: git add failed.
    exit /b 1
)

echo [2/4] git commit -m "%MSG%" ...
git commit -m "%MSG%"
if errorlevel 1 (
    echo Note: nothing to commit (or commit was not created).
    goto :push
)

:push
echo [3/4] git push ...
git push

if errorlevel 1 (
    echo.
    echo WARNING: push failed. Check NAS/SSH access, the remote URL
    echo (git remote -v) and that the repository exists on the server.
    exit /b 1
)

echo [4/4] Done. Current status:
git status -sb
echo.
echo Pushed: "%MSG%"
endlocal