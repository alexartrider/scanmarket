// ============================================================
// Запуск сканирования магазинов (блок вставляется мигратором
// tools/add_gui_scan_buttons.prg)
// ============================================================

var scanRunningProc = null;
var scanMonitorTimer = null;
var scanRunningLabel = "";
var scanResultVisible = false;
var scanAllMode = false;

var scanButtonCaption = "Сканировать";
var scanAllButtonCaption = "Сканировать все";

var scanQode = file.absolute(cfgGet(cfg, "cron.exe", "bin/qodeqt.exe"));

var scanScripts = #{
    "ozon": cfgGet(cfg, "cron.script", "ozon_scan.prg"),
    "wildberries": cfgGet(cfg, "cronWb.script", "wildberries_scan.prg"),
    "yandexmarket": cfgGet(cfg, "cronYm.script", "yandexmarket_scan.prg")
};

// Путь к скрипту сканирования магазина; "" если не задан.
function scanScriptPathFor(source)
{
    var script = str.toString(coalesce(scanScripts[source], ""));

    if (script == "")
        return "";

    return file.absolute(script);
}

// Возвращает исходные подписи кнопок.
function restoreScanButtonTexts()
{
    form.scanButton.text = scanButtonCaption;
    form.scanAllButton.text = scanAllButtonCaption;
}

// Создаёт таймер наблюдения процесса и автоматического возврата подписей.
function ensureScanMonitorTimer()
{
    if (scanMonitorTimer != null)
        return;

    scanMonitorTimer = qt.create("QTimer");

    scanMonitorTimer.timeout = function()
    {
        if (scanRunningProc == null)
        {
            if (scanResultVisible)
            {
                scanResultVisible = false;
                restoreScanButtonTexts();
                scanMonitorTimer.stop();
            }

            return;
        }

        if (!scanRunningProc.isReady)
            return;

        var r = scanRunningProc.result;
        var ok = (r != null and r.get("success") == true and r.get("code") == 0);

        finishStoreScan(ok, scanRunningLabel);
    };
}

// Показывает краткий статус ошибки запуска на кнопках.
function showScanLaunchError(message)
{
    ensureScanMonitorTimer();

    if (scanAllMode)
        form.scanAllButton.text = "Ошибка";
    else
        form.scanButton.text = "Ошибка";

    form.statusLabel.text = message;

    scanResultVisible = true;
    scanMonitorTimer.stop();
    scanMonitorTimer.start(5000);
}

// Завершение сканирования: показываем результат, включаем кнопки и обновляем таблицы.
function finishStoreScan(ok, label)
{
    scanRunningProc = null;
    scanResultVisible = true;

    form.scanButton.enabled = true;
    form.scanAllButton.enabled = true;

    if (scanAllMode)
        form.scanAllButton.text = ok ? "Готово" : "Ошибка";
    else
        form.scanButton.text = ok ? "Готово" : "Ошибка";

    form.productsGrid.refresh();
    form.historyGrid.refresh();

    form.statusLabel.text = ok
        ? "Сканирование завершено: " + label
        : "Сканирование завершилось с ошибкой: " + label;

    if (scanMonitorTimer != null)
        scanMonitorTimer.start(5000);
}

// Запускает процесс сканирования и следит за его завершением.
function launchScanProcess(scriptPath, label, allStores)
{
    scanAllMode = allStores;

    if (scriptPath == "")
    {
        showScanLaunchError("Скрипт сканирования не найден");
        return;
    }

    if (!file.exists(scanQode))
    {
        showScanLaunchError("Исполнитель не найден: " + scanQode);
        return;
    }

    form.scanButton.enabled = false;
    form.scanAllButton.enabled = false;

    if (scanAllMode)
        form.scanAllButton.text = "Сканирование…";
    else
        form.scanButton.text = "Сканирование…";

    form.statusLabel.text = "Запускается сканирование: " + label;

    scanRunningLabel = label;
    scanResultVisible = false;
    ensureScanMonitorTimer();

    scanRunningProc = system.execArgvAsync(
        #[scanQode, scriptPath],
        #{"cwd": file.getcwd(), "console": "new", "timeout": 86400000}
    );

    if (scanRunningProc == null)
    {
        scanRunningProc = null;
        finishStoreScan(false, label);
        return;
    }

    scanMonitorTimer.stop();
    scanMonitorTimer.start(1000);
}

// Кнопка «Сканировать»: сканирование выбранного магазина.
function scanButton_clicked(Sender, checked)
{
    if (scanRunningProc != null)
    {
        form.statusLabel.text = "Сканирование уже выполняется, дождитесь завершения";
        return;
    }

    launchScanProcess(scanScriptPathFor(currentSource), storeLabel(currentSource), false);
}

// Кнопка «Сканировать все»: последовательное сканирование всех магазинов.
function scanAllButton_clicked(Sender, checked)
{
    if (scanRunningProc != null)
    {
        form.statusLabel.text = "Сканирование уже выполняется, дождитесь завершения";
        return;
    }

    launchScanProcess(file.absolute("scan_all.prg"), "все магазины", true);
}
