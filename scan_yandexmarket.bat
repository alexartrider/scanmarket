@echo off
rem ScanMarket YandexMarket scan (re-run yandexmarket_setup_cron.prg to regenerate)
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"
"%PROJECT_DIR%bin\qodeqt.exe" "%PROJECT_DIR%yandexmarket_scan.prg"
