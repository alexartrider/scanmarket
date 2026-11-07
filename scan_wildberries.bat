@echo off
rem ScanMarket Wildberries scan (re-run wildberries_setup_cron.prg to regenerate)
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"
"%PROJECT_DIR%bin\qodeqt.exe" "%PROJECT_DIR%wildberries_scan.prg"
