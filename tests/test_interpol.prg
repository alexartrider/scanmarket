// test_interpol.prg — интерполяция строк \(...) c вложенными строковыми
// литералами и скобками (регрессия, P0).
//
// Ранее лексер «закрывал» внешнюю строку на внутренней кавычке внутри \(...):
//   print("\(coalesce(x, "нет"))")
//   print("\(str.toString(mm.get(0).get("mn")))")
//   print("\(str.format("%.2f", x))")
// давали syntax error. Это исправлено: парсер строки учитывает баланс скобок
// выражения и вложенные строковые литералы. Ниже все такие случаи компилируются
// и проверяются позитивно (в т.ч. через отдельный процесс qodeqt).
loadModule(file.join(file.dirname(system.getcommandline().args[0]), "..", "scriptlib", "qtestlib.prg"));

var sampleDir = file.dirname(system.getcommandline().args[0]);
var qodeqtExe = file.normalize(file.join(sampleDir, "..", "bind", "qodeqt.exe"));
if (!file.exists(qodeqtExe))
    qodeqtExe = file.normalize(file.join(sampleDir, "..", "bin", "qodeqt.exe"));
var tmp = qt_tempdir("interpol");

qt_group("интерполяция: простые выражения работают (без регрессий)");
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

qt_group("интерполяция: вложенные строковые литералы и скобки");
qt_check("coalesce со строковым литералом", "coa=\(coalesce(nullVar, "нет"))", "coa=нет");
var pi = 3.14159;
qt_check("format с форматной строкой-литералом", "pi=\(str.format("%.2f", pi))", "pi=3.14");
var mm = #[#{"mn": "март"}];
qt_check("цепочка get со строкой", "mn=\(str.toString(mm.get(0).get("mn")))", "mn=март");
qt_check("вложенные скобки", "v=\(str.toString((1 + 2) * (3 + 4)))", "v=21");
qt_check("выражение в середине строки", "left=\(x)right", "left=42right");

// ── дочерние воркеры: раньше такие файлы не компилировались ────────────────
// Воркер считает интерполированную строку и пишет её в маркер (print уходит в
// консоль/лог qodeqt, а не в OS-stdout). Теперь файлы компилируются и значение
// корреткно — проверяем содержимое маркера.
var bs = "\\";
var lp = "(";

// var val = "coa=\(coalesce(x, "нет"))";
var wCoalesce =
    "var marker = str.toString(system.getcommandline().args[1]);\n" +
    "var x = null;\n" +
    "var val = \"coa=" + bs + lp + "coalesce(x, \"нет\")" + ")" + "\";\n" +
    "file.writeatom(marker, val, #{\"enc\": \"utf8\"});\n" +
    "return 0;\n";
// var val = "pi=\(str.format("%.2f", pi))";
var wFormat =
    "var marker = str.toString(system.getcommandline().args[1]);\n" +
    "var pi = 3.14159;\n" +
    "var val = \"pi=" + bs + lp + "str.format(\"%.2f\", pi)" + ")" + "\";\n" +
    "file.writeatom(marker, val, #{\"enc\": \"utf8\"});\n" +
    "return 0;\n";
// var val = "mn=\(str.toString(mm.get(0).get("mn")))";
var wChain =
    "var marker = str.toString(system.getcommandline().args[1]);\n" +
    "var mm = #[#{\"mn\": \"март\"}];\n" +
    "var val = \"mn=" + bs + lp + "str.toString(mm.get(0).get(\"mn\"))" + ")" + "\";\n" +
    "file.writeatom(marker, val, #{\"enc\": \"utf8\"});\n" +
    "return 0;\n";

function runWorker(name, body, marker) {
    var path = file.join(tmp, name);
    file.writeatom(path, body, #{"enc": "utf8"});
    return system.execArgv(#[qodeqtExe, path, marker], #{"timeout": 30000});
}

qt_group("интерполяция: вложенные строковые литералы в дочернем процессе");
var m1 = file.join(tmp, "m_coalesce.txt");
var r1 = runWorker("iw_coalesce.prg", wCoalesce, m1);
qt_check("coalesce: код возврата 0", r1.code, 0);
qt_ok("coalesce: маркер записан (файл скомпилировался)", file.exists(m1));
qt_check("coalesce: значение корректно", file.read(m1), "coa=нет");

var m2 = file.join(tmp, "m_format.txt");
var r2 = runWorker("iw_format.prg", wFormat, m2);
qt_check("format: код возврата 0", r2.code, 0);
qt_ok("format: маркер записан", file.exists(m2));
qt_check("format: значение корректно", file.read(m2), "pi=3.14");

var m3 = file.join(tmp, "m_chain.txt");
var r3 = runWorker("iw_chain.prg", wChain, m3);
qt_check("цепочка: код возврата 0", r3.code, 0);
qt_ok("цепочка: маркер записан", file.exists(m3));
qt_check("цепочка: значение корректно", file.read(m3), "mn=март");

var rc = qt_done();
return rc;
