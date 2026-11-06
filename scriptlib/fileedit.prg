// fileedit.prg — высокоуровневая безопасная правка текстовых файлов (Python-style, но проще).
//
// Подключение (loadModule оставляет модуль в Script::Modules):
//   loadModule(file.normalize(file.join(file.dirname(system.getcommandline().app), "..", "scriptlib", "fileedit.prg")));
//
// Мгновенные атомарные правки (как раньше; opts — те же ключи, что у file.writeatom:
// { enc, overwrite, backup, verify }, по умолчанию запись UTF-8 без BOM):
//   fileedit.replaceAll(path, old, new, [opts])    — заменить все вхождения → 1 / 0
//   fileedit.replaceFirst(path, old, new, [opts])  — заменить только первое вхождение → 1 / 0
//   fileedit.edit(path, editFn, [opts])            — editFn(текст) -> новый текст
//   fileedit.filter(path, lineFn, [opts])          — построчно: lineFn(строка) -> строка (null — удалить)
//   fileedit.prepend(path, text, [opts])           — вставить текст в начало
//   fileedit.append(path, text, [opts])            — дописать текст в конец (с переводом строки)
// Мгновенные правки (кроме replace*) возвращают 0, если меня нечего — файл не трогается.
//
// Планирование + применение (безопасный цикл «сначала посмотреть, потом записать»):
//   fileedit.planReplaceAll(path, old, new)        → план
//   fileedit.planReplaceFirst(path, old, new)      → план
//   fileedit.planEdit(path, editFn)                → план
//   fileedit.planFilter(path, lineFn)              → план
//   fileedit.planPrepend(path, text)               → план
//   fileedit.planAppend(path, text)                → план
//   fileedit.planContext(path, old, new)           → план (только при единственном совпадении)
//   fileedit.apply(plan, [opts])                   → применяет план; 1 — записано, 0 — нечего менять
//
// План — обычное значение (tuple), НЕ зависит от глобального состояния:
//   #{"path", "kind", "orig", "next", "count", "diff", "enc", "bom", "old", "new", "diagnostics"}
//   orig — содержимое на момент планирования; next — новая версия; count — число
//   изменений; diff — построчный file.diff(orig, next); enc/bom — кодировка исходного
//   файла (file.readmeta) для сохранения при записи.
//
// Планирование НЕ пишет и не создаёт файл. Применение:
//   - повторно читает файл и сравнивает с планом.orig; если файл изменился после
//     планирования — конфликт (исключение), запись не выполняется;
//   - для kind="context" отказывается, если совпадений != 1 (диагностика в плане);
//   - по opts.expect сверяет ожидаемое число изменений с планом.count;
//   - записывает через file.writeatom с сохранением исходной кодировки (enc/bom из
//     плана), если не передан явный opts.enc; LF/CRLF не нормализуются;
//   - повторное применение того же плана не перезаписывает файл молча: содержимое
//     уже стало plan.next != plan.orig → конфликт.
//
// Режим сохранения кодировки (fileedit):
//   plan* фиксируют кодировку исходного файла через file.readmeta(path). apply()
//   сохраняет её при записи. Неоднозначные случаи:
//     - ASCII/UTF-8 без BOM → записывается как UTF-8 без BOM (безопасно: ASCII ⊂ UTF-8);
//     - BOM-кодировки (UTF-8 BOM, UTF-16 LE/BE) различаются по BOM;
//     - UTF-16 BE не поддержано атомарной записью → ошибка до замены файла;
//     - UTF-16 LE без BOM → запись всегда добавит BOM, поэтому правка запрещена;
//     - кодировка не распознана (file.ENC_UNKNOWN) → ошибка с требованием передать enc.
//   Обычный file.writeatom без новых параметров продолжает работать по старым
//   правилам (UTF-8 без BOM по умолчанию).

var fileedit = #tuple{};

fileedit.replaceAll = function(path, old, new, opts) {
    if (old == null || old == "") return 0;
    var text = file.read(path);
    if (str.pos(text, old) < 0) return 0;          // no-op
    var next = str.replace(text, old, str.toString(new));
    file.writeatom(path, next, opts);
    return 1;
};

fileedit.replaceFirst = function(path, old, new, opts) {
    if (old == null || old == "") return 0;
    var text = file.read(path);
    if (str.pos(text, old) < 0) return 0;
    var next = str.replaceFirst(text, old, str.toString(new));
    file.writeatom(path, next, opts);
    return 1;
};

fileedit.edit = function(path, editFn, opts) {
    var text = file.read(path);
    var next = editFn(text);
    if (next == null) throw "fileedit.edit: editFn вернул null для " + path;
    var nextStr = str.toString(next);
    if (__fe_streq(nextStr, text)) return 0;   // менять нечего — файл не трогаем
    file.writeatom(path, nextStr, opts);
    return 1;
};

fileedit.filter = function(path, lineFn, opts) {
    var text = file.read(path);
    var sp = __fe_split(text);
    var kept = #[];
    for (var i = 0; i < sp.lines.size(); i++) {
        var out = lineFn(sp.lines[i]);
        if (out != null) kept.push(str.toString(out));
    }
    // Идемпотентность: результат всегда оканчивается ровно на один "\n"
    // (если что-то осталось); "фантомная" пустая строка в lineFn не попадает.
    var next = __fe_join_lines(kept);
    if (__fe_streq(next, text)) return 0;   // нечего менять — файл не трогаем
    file.writeatom(path, next, opts);
    return kept.size();
};

fileedit.prepend = function(path, text, opts) {
    var cur = file.exists(path) ? file.read(path) : "";
    var next = str.toString(text) + cur;
    if (__fe_streq(next, cur)) return 0;    // нечего менять — файл не трогаем
    file.writeatom(path, next, opts);
    return 1;
};

fileedit.append = function(path, text, opts) {
    var orig = file.exists(path) ? file.read(path) : "";
    var base = orig;
    if (base != "" && !str.endswith(base, "\n")) base += "\n";
    var next = base + str.toString(text) + "\n";
    if (__fe_streq(next, orig)) return 0;   // нечего менять — файл не трогаем
    file.writeatom(path, next, opts);
    return 1;
};

// ── планирование ─────────────────────────────────────────────────────────────

// Собрать план из готовых частей.
function __fe_make_plan(path, kind, orig, next, count, old, newText, diag, meta) {
    return #{
        "path":         path,
        "kind":         kind,
        "orig":         orig,
        "next":         next,
        "count":        count,
        "diff":         file.diff(orig, next),
        "enc":          meta.enc,
        "bom":          meta.bom,
        "old":          old,
        "new":          newText,
        "diagnostics":  diag
    };
}

// Построчное деление для filter/planFilter. Возвращает lines — реальные строки
// (БЕЗ «фантомной» пустой строки от завершающего "\n") и hadNL — был ли в конце
// файла перевод строки. CR/LF не теряются, пустые строки в середине сохраняются.
function __fe_split(text) {
    if (text == "") return #{"lines": #[], "hadNL": 0};
    var hadNL = str.endswith(text, "\n");
    var lines = str.split(text, "\n");
    if (hadNL && lines.size() > 0 && str.len(lines[lines.size() - 1]) == 0)
        lines.pop();                       // убрать пустой элемент от финального "\n"
    return #{"lines": lines, "hadNL": hadNL};
}

// Склеить строки обратно (как filter/writeLines).
function __fe_join_lines(kept) {
    var next = "";
    for (var k = 0; k < kept.size(); k++) {
        if (k > 0) next += "\n";
        next += kept[k];
    }
    if (kept.size() > 0) next += "\n";
    return next;
}

// Точное (регистрозависимое) равенство строк. Для свежести файла, no-op и
// подсчёта изменений важны все символы: "Ab" != "ab".
function __fe_streq(a, b) {
    return a == b;
}

fileedit.planReplaceAll = function(path, old, new) {
    if (old == null || old == "") throw "fileedit.planReplaceAll: пустой шаблон old";
    var meta = file.readmeta(path);
    var orig = meta.text;
    var count = str.count(orig, old);
    var next = str.replace(orig, old, str.toString(new));
    return __fe_make_plan(path, "replaceAll", orig, next, count, old, new, "", meta);
};

fileedit.planReplaceFirst = function(path, old, new) {
    if (old == null || old == "") throw "fileedit.planReplaceFirst: пустой шаблон old";
    var meta = file.readmeta(path);
    var orig = meta.text;
    var count = (str.pos(orig, old) >= 0) ? 1 : 0;
    var next = str.replaceFirst(orig, old, str.toString(new));
    return __fe_make_plan(path, "replaceFirst", orig, next, count, old, new, "", meta);
};

fileedit.planEdit = function(path, editFn) {
    var meta = file.readmeta(path);
    var orig = meta.text;
    var next = editFn(orig);
    if (next == null) throw "fileedit.planEdit: editFn вернул null для " + path;
    var nextStr = str.toString(next);
    var count = __fe_streq(nextStr, orig) ? 0 : 1;
    return __fe_make_plan(path, "edit", orig, nextStr, count, "", "", "", meta);
};

fileedit.planFilter = function(path, lineFn) {
    var meta = file.readmeta(path);
    var orig = meta.text;
    var sp = __fe_split(orig);
    var kept = #[];
    var changed = 0;                       // число изменённых/удалённых строк
    for (var i = 0; i < sp.lines.size(); i++) {
        var inp = sp.lines[i];
        var out = lineFn(inp);
        if (out == null) { changed++; continue; }
        if (!__fe_streq(str.toString(out), inp)) changed++;
        kept.push(str.toString(out));
    }
    var next = __fe_join_lines(kept);
    return __fe_make_plan(path, "filter", orig, next, changed, "", "", "", meta);
};

fileedit.planPrepend = function(path, text) {
    var meta = file.readmeta(path);
    var orig = meta.text;
    var next = str.toString(text) + orig;
    var count = __fe_streq(next, orig) ? 0 : 1;
    return __fe_make_plan(path, "prepend", orig, next, count, "", "", "", meta);
};

fileedit.planAppend = function(path, text) {
    var meta = file.readmeta(path);
    var orig = meta.text;
    var base = orig;
    if (base != "" && !str.endswith(base, "\n")) base += "\n";
    var next = base + str.toString(text) + "\n";
    var count = __fe_streq(next, orig) ? 0 : 1;
    return __fe_make_plan(path, "append", orig, next, count, "", "", "", meta);
};

// Контекстная замена: правка применяется ТОЛЬКО при единственном совпадении old.
// При 0 или >1 совпадений план содержит диагностику (plan.diagnostics), next
// равен orig, и apply() отказывается применять план.
fileedit.planContext = function(path, old, new) {
    if (old == null || old == "") throw "fileedit.planContext: пустой шаблон old";
    var meta = file.readmeta(path);
    var orig = meta.text;
    var count = str.count(orig, old);
    var diag = "";
    if (count == 0) diag = "совпадение не найдено";
    else if (count > 1) diag = "найдено " + str.toString(count) + " совпадений — замена неоднозначна";
    var next = (count == 1) ? str.replaceFirst(orig, old, str.toString(new)) : orig;
    return __fe_make_plan(path, "context", orig, next, count, old, new, diag, meta);
};

// ── применение ───────────────────────────────────────────────────────────────

fileedit.apply = function(plan, opts) {
    // Проверка структуры плана (значение может быть произвольным — не доверяем)
    if (plan == null || !plan.has("path") || !plan.has("orig") || !plan.has("next") || !plan.has("kind"))
        throw "fileedit.apply: некорректный план (нужны path/orig/next/kind)";
    var path = str.toString(plan.path);
    var orig = str.toString(plan.orig);
    var next = str.toString(plan.next);
    var kind = str.toString(plan.kind);

    // Контекстная замена: неоднозначность — отказ без записи
    if (kind == "context" && plan.count != 1)
        throw "fileedit.apply: " + ((plan.has("diagnostics") && plan.diagnostics != null)
                                    ? str.toString(plan.diagnostics) : "неоднозначная замена");

    // Свежесть: файл перечитывается и сравнивается с содержимым на момент плана
    var current = file.read(path);
    if (!__fe_streq(current, orig))
        throw "fileedit.apply: файл изменился с момента планирования: " + path;

    // Ожидаемое число изменений
    if (opts != null && opts.has("expect") && opts.expect != plan.count)
        throw "fileedit.apply: ожидалось " + str.toString(opts.expect) +
              " изменений, в плане " + str.toString(plan.count) + ": " + path;

    // Правка ничего не меняет — файл не трогаем
    if (__fe_streq(next, orig)) return 0;

    // Кодировка записи: явный opts.enc или сохранение кодировки исходного файла
    var writeOpts = #tuple{};
    if (opts != null && opts.has("enc")) {
        writeOpts.set("enc", opts.enc);
    } else {
        var enc = plan.has("enc") ? plan.enc : file.ENC_UNKNOWN;
        var bom = plan.has("bom") ? plan.bom : 0;
        if (enc == file.ENC_UNKNOWN)
            throw "fileedit.apply: не удалось определить кодировку файла " + path + " — передайте enc явно";
        if (enc == file.ENC_UTF16_BE)
            throw "fileedit.apply: UTF-16 BE не поддержано атомарной записью: " + path;
        if (enc == file.ENC_UTF16_LE && !bom)
            throw "fileedit.apply: UTF-16 без BOM не поддержано атомарной записью (запись добавит BOM): " + path;
        writeOpts.set("enc", enc);
    }
    if (opts != null) {
        if (opts.has("backup"))   writeOpts.set("backup", opts.backup);
        if (opts.has("verify"))   writeOpts.set("verify", opts.verify);
        if (opts.has("overwrite")) writeOpts.set("overwrite", opts.overwrite);
    }

    file.writeatom(path, next, writeOpts);
    return 1;
};
