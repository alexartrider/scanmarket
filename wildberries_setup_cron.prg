// Настройка планировщика Windows (schtasks) для ежедневного запуска
// сканирования Wildberries. Запуск: bin\qodeqt.exe wildberries_setup_cron.prg
//
// Настройки берутся из секции cronWb файла config.json:
//   taskName, mode, start, everyHours, exe, script, bat, runLevel, np.
//
// Примечания по запуску команд:
//  - system.system(cmd) запускает команду через cmd.exe и возвращает код завершения,
//    но не возвращает стандартный вывод. Для чтения вывода перенаправляем его в файл.
//  - system.systemex(cmd, timeout) в этой среде возвращает ошибку даже для команды
//    "echo hi"; здесь эту функцию не используем.
//  - Если путь в параметре schtasks /tr содержит пробелы, используем BAT-файл запуска.
//    Он переходит в каталог проекта, чтобы относительный путь к PRG работал.

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");

var cfg = loadConfig("");

var taskName = cfgGet(cfg, "cronWb.taskName", "ScanMarketWildberries");
var mode = cfgGet(cfg, "cronWb.mode", "daily");
var startTime = cfgGet(cfg, "cronWb.start", "06:00");
var everyHours = cfgGet(cfg, "cronWb.everyHours", 6);
var exeName = cfgGet(cfg, "cronWb.exe", "bin/qodeqt.exe");
var scriptName = cfgGet(cfg, "cronWb.script", "wildberries_scan.prg");
var batName = cfgGet(cfg, "cronWb.bat", "scan_wildberries.bat");

var workdir = projectDir;
var exePath = file.normalize(file.join(workdir, exeName));
if (!file.exists(exePath)) {
    error("Исполняемый файл не найден: " + exePath);
    system.exit(1);
}

var scriptPath = file.normalize(file.join(workdir, scriptName));
if (!file.exists(scriptPath)) {
    error("Скрипт задачи не найден: " + scriptPath);
    system.exit(1);
}

// ---------- BAT-файл для запуска ----------
var batPath = file.join(workdir, batName);
var bat = "@echo off\r\n";
bat = bat + "rem ScanMarket Wildberries scan (re-run wildberries_setup_cron.prg to regenerate)\r\n";
bat = bat + "cd /d \"" + workdir + "\"\r\n";
bat = bat + "\"" + exePath + "\" \"" + scriptPath + "\"\r\n";
file.write(batPath, bat, file.ENC_CP1251);
print("Создан BAT-файл: \(batPath)");

// ---------- helpers ----------
var qfile = "private_data/wildberries/cron_task.txt";
file.mkdirrecursive(file.dirname(qfile));

function runCmd(label, cmd) {
    var r = null;
    try { r = system.system(cmd); } catch (e) { r = null; }
    if (r == null) {
        print("\(label): ошибка выполнения команды или пустой результат.");
        return -999;
    }
    print("\(label): код завершения=\(str.toString(r))");
    return str.toInt(str.toString(r));
}

function readOut(label) {
    var t = "";
    try { t = file.read(qfile, file.ENC_CP1251); } catch (e) { t = ""; }
    if (t == null) t = "";
    if (t == "") {
        try { t = file.read(qfile, file.ENC_UTF8_BOM); } catch (e2) { t = ""; }
    }
    if (t == null) t = "";
    print("\(label): вывод команды: \(str.sub(str.trim(t), 0, 400))");
}

// ---------- удаление существующей задачи ----------
var dq = runCmd("Удаление задачи", "schtasks /delete /tn \"" + taskName + "\" /f > " + qfile + " 2>&1");
readOut("Удаление задачи");

// ---------- create task ----------
var sched = "/sc daily /st " + startTime;
if (mode == "hourly") sched = "/sc hourly /mo " + str.toString(everyHours);
var runLevel = cfgGet(cfg, "cronWb.runLevel", "");
if (runLevel != null and runLevel != "") sched = sched + " /rl " + str.toString(runLevel);
var npFlag = cfgGet(cfg, "cronWb.np", 0);
if (npFlag != null and str.toInt(str.toString(npFlag)) == 1) sched = sched + " /np";

var create = "schtasks /create /tn \"" + taskName + "\" /tr \"" + batPath + "\" " + sched
    + " > " + qfile + " 2>&1";
var cr = runCmd("Создание задачи", create);
readOut("Создание задачи");
if (cr != 0) {
    error("Не удалось создать задачу планировщика (код завершения=\(str.toString(cr))).");
    system.exit(2);
}

// ---------- verify ----------
var qr = runCmd("Проверка задачи", "schtasks /query /tn \"" + taskName + "\" /fo list > " + qfile + " 2>&1");
readOut("Проверка задачи");

print("Задача планировщика: \(taskName), режим=\(mode), запуск=\(startTime), интервал=\(str.toString(everyHours)) ч.");
print("Для немедленного запуска выполните: schtasks /run /tn \"" + taskName + "\"");
return 0;
