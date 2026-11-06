@echo off
setlocal enabledelayedexpansion
rem ============================================================
rem  ScanMarket: Git commit + push helper
rem  Использование:
rem    gitpush.bat                     -> коммит с сообщением по умолчанию
rem    gitpush.bat "сообщение коммита" -> коммит с вашим сообщением
rem  Приватное (private_data\, bin\log\, log\) игнорируется через .gitignore.
rem ============================================================

set "MSG=%~1"
if "%MSG%"=="" set "MSG=ScanMarket: update"

cd /d "%~dp0"

echo [1/4] git add -A ...
git add -A
if errorlevel 1 (
    echo ОШИБКА: git add не удался.
    exit /b 1
)

echo [2/4] git commit -m "%MSG%" ...
git commit -m "%MSG%"
if errorlevel 1 (
    echo Замечание: могло быть нечего коммитить ^(или коммит не создан^).
    goto :branch
)

:branch
echo [3/4] git push ...
git push

if errorlevel 1 (
    echo.
    echo ВНИМАНИЕ: push не удался. Проверьте доступ к NAS/SSH, URL remote
    echo ^(`git remote -v`^) и что репозиторий существует на сервере.
    exit /b 1
)

echo [4/4] Готово. Проверьте статус:
git status -sb
echo.
echo Отправлено: "%MSG%"
endlocal
