// qtestlib.prg — мини-библиотека тестов для утилит Script/Qode.
//
// Подключение из теста (loadModule оставляет модуль в Script::Modules,
// поэтому его функции и общее состояние видны из вызывающего теста;
// execute(...) НЕ подходит — он выгружает модуль сразу после возврата):
//   loadModule(file.normalize(file.join(file.dirname(system.getcommandline().app), "..", "scriptlib", "qtestlib.prg")));
//
// Предоставляет:
//   qt_group(name)                         — печатает заголовок группы
//   qt_check(desc, actual, expected)       — сравнение через '=='
//   qt_checkJson(desc, actual, expected)   — сравнение через json.stringify
//   qt_checkExact(desc, actual, expected)  — строгое сравнение строк после toString
//   qt_ok(desc, cond)                     — проверка булева
//   qt_fail(desc, msg)                    — безусловный FAIL
//   qt_throws(desc, fn, [pattern])        — fn должен выбросить исключение
//   qt_done()                             — итоговый отчёт, возвращает fail/summaries
//   qt_tempdir([prefix])                  — уникальная временная директория
//   qt_run(program, argsArray, [timeout]) — запуск процесса с захватом вывода
//   qt_quoteArg(a)                        — экранирование аргумента командной строки
//
// Все файловые тесты должны работать только во временной директории (qt_tempdir).

var __qt_name  = "tests";
var __qt_pass  = 0;
var __qt_fail  = 0;
var __qt_total = 0;
// кумулятивные счётчики всего прогона (qt_group сбрасывает только групповые)
var __qt_pass_all  = 0;
var __qt_fail_all  = 0;
var __qt_total_all = 0;

function qt_group(name) {
    __qt_name = (name == null) ? "tests" : ("" + name);
    __qt_pass = 0; __qt_fail = 0; __qt_total = 0;
    print("=== " + __qt_name + " ===");
}

function qt_done() {
    print("----");
    print("Результаты: " + __qt_pass + " OK, " + __qt_fail + " FAIL, всего " + __qt_total + " (группа '" + __qt_name + "')");
    print("Итого:      " + __qt_pass_all + " OK, " + __qt_fail_all + " FAIL, всего " + __qt_total_all);
    if (__qt_fail_all > 0) { print("РЕЗУЛЬТАТ: FAIL"); return 1; }
    print("РЕЗУЛЬТАТ: PASS");
    return 0;
}

function qt_check(desc, actual, expected) {
    __qt_total++; __qt_total_all++;
    if (actual == expected) { __qt_pass++; __qt_pass_all++; print("  OK:   " + desc); }
    else { __qt_fail++; __qt_fail_all++; print("  FAIL: " + desc + "  expected=" + json.stringify(expected) + "  actual=" + json.stringify(actual)); }
}

function qt_checkJson(desc, actual, expected) {
    __qt_total++; __qt_total_all++;
    var a = json.stringify(actual);
    var e = json.stringify(expected);
    if (a == e) { __qt_pass++; __qt_pass_all++; print("  OK:   " + desc); }
    else { __qt_fail++; __qt_fail_all++; print("  FAIL: " + desc + "  expected=" + e + "  actual=" + a); }
}

// Строгое сравнение строк после преобразования аргументов в строку.
// Годится для проверки маркеров/содержимого, где "DONE" != "done".
function qt_checkExact(desc, actual, expected) {
    __qt_total++; __qt_total_all++;
    var a = str.toString(actual);
    var e = str.toString(expected);
    var same = (str.len(a) == str.len(e)) && (str.pos(a, e) == 0);
    if (same) { __qt_pass++; __qt_pass_all++; print("  OK:   " + desc); }
    else { __qt_fail++; __qt_fail_all++; print("  FAIL: " + desc + "  expected=" + json.stringify(expected) + "  actual=" + json.stringify(actual)); }
}

function qt_ok(desc, cond) {
    __qt_total++; __qt_total_all++;
    if (cond) { __qt_pass++; __qt_pass_all++; print("  OK:   " + desc); }
    else { __qt_fail++; __qt_fail_all++; print("  FAIL: " + desc); }
}

function qt_fail(desc, msg) {
    __qt_total++; __qt_total_all++;
    __qt_fail++; __qt_fail_all++;
    print("  FAIL: " + desc + (msg == null ? "" : "  (" + msg + ")"));
}

function qt_throws(desc, fn, pattern) {
    __qt_total++; __qt_total_all++;
    try {
        fn();
        __qt_fail++; __qt_fail_all++;
        print("  FAIL: " + desc + "  — исключение не было выброшено");
    } catch (e) {
        var msg = str.toString(e);
        if (pattern != null && str.pos(msg, pattern) < 0) {
            __qt_fail++; __qt_fail_all++;
            print("  FAIL: " + desc + "  — сообщение не содержит '" + pattern + "': " + msg);
        } else {
            __qt_pass++; __qt_pass_all++;
            print("  OK:   " + desc);
        }
    }
}

function qt_tempdir(prefix) {
    var base = file.tempdir();
    var pfx = (prefix == null) ? "qtest" : ("" + prefix);
    for (var i = 0; i < 10000; i++) {
        var p = file.join(base, pfx + "_" + str.toString(i));
        if (!file.exists(p)) { file.mkdirrecursive(p); return p; }
    }
    throw "qt_tempdir: не удалось создать уникальную директорию в " + base;
}

function qt_quoteArg(a) {
    var s = str.toString(a);
    if (str.pos(s, " ") < 0 && str.pos(s, "\t") < 0) return s;
    return "\"" + str.replace(s, "\"", "\\\"") + "\"";
}

function qt_run(program, argsArray, timeoutMs) {
    var cmd = qt_quoteArg(program);
    if (argsArray != null) {
        for (var k = 0; k < argsArray.size(); k++)
            cmd += " " + qt_quoteArg(argsArray[k]);
    }
    var timeout = (timeoutMs == null) ? 30000 : timeoutMs;
    return system.exec(cmd, timeout);
}
