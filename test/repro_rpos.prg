// repro_rpos.prg — минимальный репро дефекта Qode: str.rpos описан в
// docs/specs/qode.md, но отсутствует в рантайме.
// Запуск: bin\qodeqt.exe test\repro_rpos.prg

function probe(label, fn) {
    var result = null;
    var thrown = null;
    try {
        result = fn();
    } catch (e) {
        thrown = e;
    }
    var line = "  " + label + ": ";

    if (thrown != null)
        line = line + "ИСКЛЮЧЕНИЕ [" + str.toString(thrown) + "]";
    else if (result == null)
        line = line + "null";
    else if (result.isnumber())
        line = line + str.toString(result) + " (тип " + typeName(result) + ")";
    else
        line = line + str.toString(result) + " (тип " + typeName(result) + ")";

    print(line);
}

print("=== Наличие методов в пространстве str ===");
print("  methodExists(str, 'rpos') = " + str.toString(methodExists(str, "rpos")));
print("  methodExists(str, 'rfind') = " + str.toString(methodExists(str, "rfind")));
print("  methodExists(str, 'pos') = " + str.toString(methodExists(str, "pos")));

print("=== Вызовы namespace-функций ===");
probe("str.rpos(\"a-b-a\", \"-\")  // ожидание по docs: 3", function () { return str.rpos("a-b-a", "-"); });
probe("str.rfind(\"a-b-a\", \"-\")", function () { return str.rfind("a-b-a", "-"); });
probe("str.pos(\"a-b-a\", \"-\")", function () { return str.pos("a-b-a", "-"); });
probe("str.rpos(\"abc\", \"z\")    // ожидание по docs: -1", function () { return str.rpos("abc", "z"); });
probe("str.rfind(\"abc\", \"z\")", function () { return str.rfind("abc", "z"); });

print("=== Способы вызова на строке ===");
probe("'a-b-a'.rfind('-')?", function () { return "a-b-a".rfind("-"); });

print("=== Итог ===");
if (methodExists(str, "rpos")) {
    var v = null;
    try { v = str.rpos("a-b-a", "-"); } catch (e) { v = null; }
    if (v == 3) {
        print("str.rpos работает корректно — дефект отсутствует.");
        return 0;
    }
    print("str.rpos есть, но возвращает не 3 (см. выше).");
    return 1;
}
print("str.rpos отсутствует (methodExists=false) либо вызов неверный.");
return 1;
