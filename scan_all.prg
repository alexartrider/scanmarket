// scan_all.prg — последовательное сканирование всех магазинов (Ozon, Wildberries, Яндекс Маркет).
// Запускается кнопкой «Сканировать все» в GUI и может использоваться планировщиком.
// Каждый магазин сканируется отдельным процессом qodeqt: bin\qodeqt.exe <магазин>_scan.prg.
// Код возврата: 0 — все успешны, 1 — есть ошибки.

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");

var cfg = loadConfig("");

// Исполнитель и скрипты берём из config.json (как при настройке крона).
var qodeExe = file.absolute(cfgGet(cfg, "cron.exe", "bin/qodeqt.exe"));

var scanScripts = #{
    "ozon": cfgGet(cfg, "cron.script", "ozon_scan.prg"),
    "wildberries": cfgGet(cfg, "cronWb.script", "wildberries_scan.prg"),
    "yandexmarket": cfgGet(cfg, "cronYm.script", "yandexmarket_scan.prg")
};

var storeLabels = #{
    "ozon": "Ozon",
    "wildberries": "Wildberries",
    "yandexmarket": "Яндекс Маркет"
};

var order = #["ozon", "wildberries", "yandexmarket"];

var failed = 0;
var results = #[];

for (var i = 0; i < order.size(); i++)
{
    var source = order[i];
    var scriptRel = str.toString(coalesce(scanScripts[source], ""));
    var scriptPath = file.absolute(scriptRel);
    var label = str.toString(coalesce(storeLabels[source], source));

    if (scriptRel == "" or !file.exists(scriptPath))
    {
        print("Пропуск " + label + ": скрипт не найден (" + scriptPath + ")");
        failed = 1;
        continue;
    }

    if (!file.exists(qodeExe))
    {
        print("Ошибка: исполнитель не найден (" + qodeExe + ")");
        failed = 1;
        continue;
    }

    print("Сканирование " + label + ": " + scriptPath);
    var res = system.execArgv(#[qodeExe, scriptPath], #{"cwd": projectDir, "timeout": 21600000});

    var ok = (res != null and res.success and res.code == 0);
    results.push(#{"source": source, "ok": ok, "code": (res == null) ? -1 : res.code});

    if (ok)
        print("Готово " + label);
    else
    {
        print("Ошибка " + label + (res == null ? "" : " (код " + str.toString(res.code) + ")"));
        failed = 1;
    }
}

print("----");

for (var r = 0; r < results.size(); r++)
    print("Сканирование " + str.toString(coalesce(storeLabels[results[r].source], results[r].source))
        + ": " + (results[r].ok ? "OK" : "FAIL"));

if (failed != 0)
{
    print("Есть ошибки сканирования");
    return 1;
}

print("Все магазины отсканированы успешно");
return 0;
