@echo off
rem ScanMarket Wildberries auth
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"
"%PROJECT_DIR%bin\qodeqt.exe" "%PROJECT_DIR%wildberries_auth.prg"
