@echo off
rem ScanMarket YandexMarket auth
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"
"%PROJECT_DIR%bin\qodeqt.exe" "%PROJECT_DIR%yandexmarket_auth.prg"
