@echo off
rem ScanMarket Ozon scan (re-run ozon_setup_cron.prg to regenerate)
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"
"%PROJECT_DIR%bin\qodegui.exe" "%PROJECT_DIR%scanmarket_gui.json"
