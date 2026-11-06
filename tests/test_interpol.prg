// test_interpol.prg — фиксация ограничения интерполяции строк (регрессия).
//
// Задокументированное поведение движка НА ДАННЫЙ МОМЕНТ:
//   1) Простая интерполяция "x=\(expr)" работает: несколько выражений,
//      включая вызов str.format с форматной строкой-ПЕРЕМЕННОЙ.
//   2) Строковый ЛИТЕРАЛ внутри интерполяции \(...) — например
//        print("\(coalesce(x, "нет"))")
//        print("\(str.toString(mm.get(0).get("mn")))")
//      — даёт СИНТАКСИЧЕСКУЮ ошибку компиляции: лексер не переключается
//      в режим строки внутри \(...) и "закрывает" внешнюю строку на внутренних
//      кавычках. Рекомендуемый обход — выносить подстановку в отдельную
//      переменную (проверяется в конце теста).
//
// Тест НЕ «чинит» это поведение, а только фиксирует его, чтобы изменения
// движка не происходили молча.
//
// ВАЖНО (факт движка): qodeqt при синтаксической ошибке в файле завершается
// с кодом 0 (как при успешном выполнении), а сообщение пишет в общий лог
// qt/bin/log. Поэтому проверка «файл не выполнился» ведётся по отсутствию
// файла-маркера, который воркер пишет в самом конце, а не по коду возврата.
loadModule(file.join(file.dirname(system.getcommandline().args[0]), "..", "scriptlib", "qtestlib.prg"));

var sampleDir = file.dirname(system.getcommandline().args[0]);
var qodeqtExe = file.normalize(file.join(sampleDir, "..", "bin", "qodeqt.exe"));
var tmp = qt_tempdir("interpol");

qt_group("интерполяция: простые выражения работают");
var x = 42;
var nullVar = null;
var fmtNum = "%d -> %d";
qt_check("переменная", "x=\(x)", "x=42");
qt_check("арифметика", "sum=\(x + 8)", "sum=50");
qt_check("унарный минус", "neg=\(-x)", "neg=-42");
qt_check("остаток", "mod=\(x % 5)", "mod=2");
qt_check("coalesce (без строкового литерала)", "coa=\(coalesce(nullVar, 5))", "coa=5");
qt_check("str.toString", "st=\(str.toString(x))", "st=42");
qt_check("str.format с форматной строкой-переменной", "fmt=\(str.format(fmtNum, 1, 2))", "fmt=1 -> 2");

// ── дочерние воркеры ─────────────────────────────────────────────────────────
// Воркер сам пишет маркер "DONE" ПОСЛЕ проверяемой строки. Если в проверяемой
// строке синтаксическая ошибка — файл не компилируется и маркер не пишется.
function workerBody(lines) {
    var out = "var marker = str.toString(system.getcommandline().args[1]);\n";
    for (var k = 0; k < lines.size(); k++) out += lines[k] + "\n";
    out += "file.writeatom(marker, \"DONE\", #{\"enc\": \"utf8\"});\n";
    out += "return 0;\n";
    return out;
}

// \( — в скрипте нельзя записать литерал «\(» внутри одной строки (любой
// \( начинает интерполяцию), поэтому собираем его из обратного слеша и '('.
var bs = "\\";
var lp = "(";

// контрольный воркер: обычная интерполяция работает
var okBody = workerBody(#[
    "var x = 42;",
    "print(\"x=" + bs + lp + "x)" + "\"" + ");"
]);
// воркеры с ЗАПРЕЩЁННЫМ вложенным строковым литералом внутри \(...):
//   print("coa=\(coalesce(x, "нет"))")
var badCoalesce = workerBody(#[
    "var x = 42;",
    "print(\"coa=" + bs + lp + "coalesce(x, \"нет\")" + ")" + "\"" + ");"
]);
//   print("pi=\(str.format("%.2f", pi))")   — форматная строка ЛИТЕРАЛОМ внутри \(...)
var badFormat = workerBody(#[
    "var pi = 3.14159;",
    "print(\"pi=" + bs + lp + "str.format(\"%.2f\", pi)" + ")" + "\"" + ");"
]);
//   print("mn=\(str.toString(mm.get(0).get("mn")))")
var badChain = workerBody(#[
    "var mm = #[#{\"mn\": \"март\"}];",
    "print(\"mn=" + bs + lp + "str.toString(mm.get(0).get(\"mn\"))" + ")" + "\"" + ");"
]);
// обходной путь: подстановка вынесена в отдельную переменную — компилируется
var fixBody = workerBody(#[
    "var x = 42;",
    "var res = coalesce(x, " + "\"нет\"" + ");",
    "print(\"coa=" + bs + lp + "res)" + "\"" + ");"
]);

function runWorker(name, body, marker) {
    var path = file.join(tmp, name);
    file.writeatom(path, body, #{"enc": "utf8"});
    return system.execArgv(#[qodeqtExe, path, marker], #{"timeout": 30000});
}

qt_group("интерполяция: контрольный воркер (обычная интерполяция выполняется)");
var mOk = file.join(tmp, "m_ok.txt");
var rOk = runWorker("iw_ok.prg", okBody, mOk);
qt_check("контрольный воркер: код возврата 0", rOk.code, 0);
qt_ok("контрольный воркер: маркер записан (файл выполнился)", file.exists(mOk));
qt_check("контрольный воркер: маркер=DONE", file.read(mOk), "DONE");

qt_group("интерполяция: вложенный строковый литерал — ограничение движка");
var mBad1 = file.join(tmp, "m_bad_coalesce.txt");
var rBad1 = runWorker("iw_bad_coalesce.prg", badCoalesce, mBad1);
// факт движка: синтаксическая ошибка НЕ меняет код возврата (exit=0)
qt_check("coalesce: код возврата 0 (движок не различает)", rBad1.code, 0);
qt_ok("coalesce: маркер НЕ записан (файл не скомпилировался)", !file.exists(mBad1));

var mBad2 = file.join(tmp, "m_bad_format.txt");
var rBad2 = runWorker("iw_bad_format.prg", badFormat, mBad2);
qt_check("format с литералом: код возврата 0 (движок не различает)", rBad2.code, 0);
qt_ok("format с литералом: маркер НЕ записан (файл не скомпилировался)", !file.exists(mBad2));

var mBad3 = file.join(tmp, "m_bad_chain.txt");
var rBad3 = runWorker("iw_bad_chain.prg", badChain, mBad3);
qt_check("цепочка с литералом: код возврата 0 (движок не различает)", rBad3.code, 0);
qt_ok("цепочка с литералом: маркер НЕ записан (файл не скомпилировался)", !file.exists(mBad3));

qt_group("интерполяция: обход — подстановка в отдельную переменную");
var mFix = file.join(tmp, "m_fix.txt");
var rFix = runWorker("iw_fix.prg", fixBody, mFix);
qt_check("обход: код возврата 0", rFix.code, 0);
qt_ok("обход: маркер записан (файл выполнился)", file.exists(mFix));
qt_check("обход: маркер=DONE", file.read(mFix), "DONE");

var rc = qt_done();
return rc;
