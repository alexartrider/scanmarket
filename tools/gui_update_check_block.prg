// ============================================================
// Проверка обновлений ресурсов ScanMarket из GitHub
// ============================================================

var updateCheckButtonCaption = "Проверить обновления";
var updateCheckProc = null;
var updateCheckTimer = null;
var updateCheckOutputFile = "";
var updateCheckScript = file.absolute("tools/check_github_updates.prg");
var updateCheckQode = file.absolute(cfgGet(cfg, "cron.exe", "bin/qodeqt.exe"));

function clearUpdateCheckOutputFiles()
{
    if (updateCheckOutputFile != "" and file.exists(updateCheckOutputFile))
        file.remove(updateCheckOutputFile);

    updateCheckOutputFile = "";
}

function ensureUpdateCheckTimer()
{
    if (updateCheckTimer != null)
        return;

    updateCheckTimer = qt.create("QTimer");
    updateCheckTimer.timeout = updateCheckTimer_timeout;
}

function finishUpdateCheck(message)
{
    updateCheckProc = null;
    updateCheckTimer.stop();
    clearUpdateCheckOutputFiles();
    form.checkUpdatesButton.enabled = true;
    form.checkUpdatesButton.text = updateCheckButtonCaption;
    form.statusLabel.text = message;
}

function updateCheckTimer_timeout()
{
    if (updateCheckProc == null or !updateCheckProc.isReady)
        return;

    var processResult = updateCheckProc.result;
    if (processResult == null)
    {
        finishUpdateCheck("Не удалось получить результат проверки GitHub");
        return;
    }

    var resultText = "";
    if (updateCheckOutputFile != "" and file.isfile(updateCheckOutputFile))
        resultText = str.toString(file.read(updateCheckOutputFile));

    if (processResult.get("success") != true or processResult.get("code") != 0)
    {
        var errorText = "Код завершения: " + str.toString(processResult.get("code"));
        if (resultText != "")
        {
            try
            {
                var errorResult = json.parse(resultText);
                errorText = str.toString(coalesce(errorResult.get("error"), errorText));
            }
            catch (e)
            {
                // Используем код завершения, если worker не оставил JSON-диагностику.
            }
        }
        finishUpdateCheck("Ошибка проверки обновлений: " + errorText);
        return;
    }

    var result = null;
    try
    {
        result = json.parse(resultText);
    }
    catch (e)
    {
        finishUpdateCheck("Не удалось разобрать ответ проверки GitHub");
        return;
    }

    if (result == null or result.get("ok") != true)
    {
        var error = result == null
            ? "Проверка GitHub не вернула результат"
            : str.toString(coalesce(result.get("error"), "Неизвестная ошибка"));
        finishUpdateCheck("Ошибка проверки обновлений: " + error);
        return;
    }

    var warning = str.toString(coalesce(result.get("warning"), ""));
    var changed = result.get("changed");
    if (changed == null or changed.empty())
    {
        var currentMessage = "Файлы актуальны (проверено: "
            + str.toString(result.get("checked")) + ")";
        if (warning != "")
            currentMessage += ". " + warning;
        finishUpdateCheck(currentMessage);
        return;
    }

    var message = "Есть изменения (" + str.toString(changed.size()) + "): ";
    var shown = changed.size();
    if (shown > 3)
        shown = 3;

    for (var i = 0; i < shown; i++)
    {
        if (i > 0)
            message += ", ";
        message += str.toString(changed[i]);
    }

    if (changed.size() > shown)
        message += " и ещё " + str.toString(changed.size() - shown);

    if (warning != "")
        message += ". " + warning;

    finishUpdateCheck(message);
}

function checkUpdatesButton_clicked(Sender, checked)
{
    if (updateCheckProc != null)
    {
        form.statusLabel.text = "Проверка обновлений уже выполняется";
        return;
    }

    if (scanRunningProc != null)
    {
        form.statusLabel.text = "Сначала дождитесь завершения сканирования";
        return;
    }

    if (!file.isfile(updateCheckQode))
    {
        form.statusLabel.text = "Исполнитель не найден: " + updateCheckQode;
        return;
    }

    if (!file.isfile(updateCheckScript))
    {
        form.statusLabel.text = "Скрипт проверки не найден: " + updateCheckScript;
        return;
    }

    ensureUpdateCheckTimer();
    clearUpdateCheckOutputFiles();
    updateCheckOutputFile = file.tempfile();

    if (updateCheckOutputFile == "")
    {
        clearUpdateCheckOutputFiles();
        form.statusLabel.text = "Не удалось создать временные файлы для проверки";
        return;
    }

    form.checkUpdatesButton.enabled = false;
    form.checkUpdatesButton.text = "Проверка…";
    form.statusLabel.text = "Проверка файлов на GitHub…";

    updateCheckProc = system.execArgvAsync(
        #[updateCheckQode, updateCheckScript, updateCheckOutputFile],
        #{
            "cwd": file.getcwd(),
            "timeout": 120000,
            "console": "detached"
        }
    );

    if (updateCheckProc == null)
    {
        finishUpdateCheck("Не удалось запустить проверку GitHub");
        return;
    }

    updateCheckTimer.start(250);
}
