// run_tests.prg — запуск всех (или выбранных) test_*.prg одним вызовом и итог.
//
// Использование:
//   qodeqt run_tests.prg                       — все test_*.prg в этом каталоге
//   qodeqt run_tests.prg test_json*.prg        — только по шаблону (glob)
//   qodeqt run_tests.prg test_fileedit.prg test_db_qt.prg   — конкретные имена
//   qodeqt run_tests.prg --timeout=30000 test_json_file.prg — свой таймаут (мс)
//
// Каждый тест — отдельный процесс qodeqt через system.execArgv (без shell,
// пути с пробелами/Unicode безопасны). PASS = exit code 0, иначе FAIL.
// Код возврата раннера: 0 = все прошли, 1 = есть падения.
// Вывод тестов идёт в общий лог qt/bind/log; итог раннера — в конце.

var sampleDir = file.dirname(system.getcommandline().args[0]);
var qodeqt    = file.normalize(file.join(sampleDir, "..", "bin", "qodeqt.exe"));
var timeoutMs = 120000;

// аргументы: имена/шаблоны тестов + опция --timeout=
var want = #[];
{
    var args = system.getcommandline().args;
    for (var i = 1; i < args.size(); i++) {
        var a = str.toString(args[i]);
        if (str.startswith(a, "--timeout=")) {
            var t = str.toInt(str.sub(a, str.len("--timeout=")));
            if (t > 0) timeoutMs = t;
        } else {
            want.push(a);
        }
    }
}

// собрать список файлов тестов
var tests = #[];
if (want.size() == 0) {
    var all = file.glob(file.join(sampleDir, "test_*.prg"));
    for (var k = 0; k < all.size(); k++) tests.push(file.basename(all[k]));
} else {
    for (var w = 0; w < want.size(); w++) {
        var pat = want[w];
        if (str.pos(pat, "*") >= 0 || str.pos(pat, "?") >= 0) {
            var m = file.glob(file.join(sampleDir, pat));
            for (var q = 0; q < m.size(); q++) tests.push(file.basename(m[q]));
        } else {
            tests.push(pat);
        }
    }
}

// дедупликация с сохранением порядка (линейный поиск — тестов немного)
var uniq = #[];
for (var t = 0; t < tests.size(); t++) {
    var n = tests[t];
    if (n == "run_tests.prg") continue;
    var dup = 0;
    for (var u = 0; u < uniq.size(); u++) if (uniq[u] == n) { dup = 1; break; }
    if (!dup) uniq.push(n);
}
if (uniq.size() == 0) {
    print("Нет тестов для запуска (test_*.prg в " + sampleDir + " не найдены)");
    return 0;
}

var passCnt = 0, failCnt = 0;
var failures = #[];
print("=== Запуск " + uniq.size() + " тестов, таймаут " + str.toString(timeoutMs) + " мс ===");
for (var i = 0; i < uniq.size(); i++) {
    var name = uniq[i];
    var path = file.join(sampleDir, name);
    if (!file.exists(path)) {
        failCnt++;
        print("FAIL " + name + " (файл не найден)");
        failures.push(name);
        continue;
    }
    print(">>> " + name);
    var res = system.execArgv(#[qodeqt, path], #{"timeout": timeoutMs});
    if (res.success) {
        passCnt++;
        print("PASS " + name);
    } else {
        failCnt++;
        print("FAIL " + name + " (exit=" + str.toString(res.code) + (res.code < 0 ? ", timeout/убит" : "") + ")");
        failures.push(name);
    }
}
print("----");
print("Итог: " + passCnt + " PASS, " + failCnt + " FAIL, всего " + uniq.size());
if (failCnt > 0) {
    print("Завалились: " + json.stringify(failures));
    return 1;
}
print("Все тесты прошли.");
return 0;
