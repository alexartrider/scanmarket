// funcedit.prg — безопасное редактирование функций в исходном коде Script.
//
// Подключение (loadModule оставляет функции в Script::Modules):
//   loadModule(file.normalize(file.join(file.dirname(system.getcommandline().app), "..", "scriptlib", "funcedit.prg")));
//
// API (namespace funcedit):
//   funcedit.find(source, name)            — ровно одна функция: #{"start", "bodyStart", "bodyClose", "end"}
//                                          — иначе понятная ошибка (0 или несколько совпадений)
//   funcedit.exists(source, name)          — есть ли хотя бы одно совпадение
//   funcedit.isUnique(source, name)        — ровно ли одно совпадение
//   funcedit.getBody(source, name)         — текст тела функции (между { и })
//   funcedit.replaceBody(source, name, newBody) — замена только тела
//   funcedit.replace(source, name, newSource)   — замена всей функции
//   funcedit.insertBefore(source, name, snippet) — вставка фрагмента перед словом "function"
//   funcedit.insertAfter(source, name, snippet)  — вставка фрагмента после закрывающей "}"
//   funcedit.balanced(source)              — баланс () [] {} с учётом строк и комментариев
//
// Находит объявления вида "function Имя(...) { ... }" (в т.ч. внутри классов).
// Подстроки "function" внутри строк/комментариев игнорируются.
// Изменение исходника никогда не выполняется серией str.replace(): только по найденным границам.

var funcedit = #tuple{};

var FUNC_KW_LEN = 8;  // длина "function"

// Маска 1/0: позиция принадлежит коду (не строке/комментарию)
function __fec_mask(source) {
    var n = str.len(source);
    var mask = #[];
    for (var i = 0; i < n; i++) mask.push(1);
    var i = 0;
    var inLine = 0, inBlock = 0;
    while (i < n) {
        var c = str.mid(source, i, 1);
        var d = str.mid(source, i, 2);
        if (inLine) {
            mask[i] = 0;
            if (c == "\n") inLine = 0;
            i++;
            continue;
        }
        if (inBlock) {
            mask[i] = 0;
            if (d == "*/") { mask[i] = 0; if (i + 1 < n) mask[i + 1] = 0; i += 2; inBlock = 0; continue; }
            i++;
            continue;
        }
        if (d == "//") { mask[i] = 0; if (i + 1 < n) mask[i + 1] = 0; i += 2; inLine = 1; continue; }
        if (d == "/*") { mask[i] = 0; if (i + 1 < n) mask[i + 1] = 0; i += 2; inBlock = 1; continue; }
        if (c == "\"" || c == "'") {
            var q = c;
            mask[i] = 0;
            i++;
            while (i < n) {
                var cc = str.mid(source, i, 1);
                if (cc == "\\") { mask[i] = 0; if (i + 1 < n) mask[i + 1] = 0; i += 2; continue; }
                mask[i] = 0;
                if (cc == q) { i++; break; }
                if (cc == "\n") { i++; break; }   // строка не может содержать перевод (защита от "утечки")
                i++;
            }
            continue;
        }
        i++;
    }
    return mask;
}

// Индекс совпадающей закрывающей скобки для открывающей в позиции from (mask == 1).
// source[from] должен быть равен open. Возвращает индекс close или -1.
function __fec_balanced_end(source, from, open, close, mask) {
    var n = str.len(source);
    var depth = 0;
    for (var i = from; i < n; i++) {
        if (mask[i] != 1) continue;
        var c = str.mid(source, i, 1);
        if (c == open) depth++;
        else if (c == close) {
            depth--;
            if (depth == 0) return i;
        }
    }
    return -1;
}

// identifier сразу после ключевого слова function
function __fec_read_name(source, pos, mask) {
    var n = str.len(source);
    var j = pos + FUNC_KW_LEN;
    while (j < n && (str.mid(source, j, 1) == " " || str.mid(source, j, 1) == "\t" || str.mid(source, j, 1) == "\r" || str.mid(source, j, 1) == "\n")) j++;
    var s = j;
    while (j < n) {
        var ch = str.mid(source, j, 1);
        if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9") || ch == "_") j++;
        else break;
    }
    if (j == s) return null;
    return #{"name": str.mid(source, s, j - s), "nameEnd": j};
}

// Все функции вида function name(...) { ... }
function __fec_find_all(source) {
    var n = str.len(source);
    var mask = __fec_mask(source);
    var positions = str.positions(source, "function");
    var found = #[];
    for (var k = 0; k < positions.size(); k++) {
        var pi = positions[k];
        if (mask[pi] != 1) continue;
        // ключевое слово должно быть отдельно от других букв: перед ним не буква
        var before = (pi > 0) ? str.mid(source, pi - 1, 1) : "";
        var prevOk = (before == "" || before == " " || before == "\t" || before == "\r" || before == "\n" || before == "(" || before == ";" || before == "{" || before == "}");
        if (!prevOk) continue;
        var nm = __fec_read_name(source, pi, mask);
        if (nm == null) continue;
        // после имени: пропустить пробелы и (если задан) 'export', затем '(' ... ')' и '{'
        var j = nm.nameEnd;
        var skip = 1;
        while (j < n && skip) {
            var w = str.mid(source, j, 7);
            if (str.mid(source, j, 1) == " " || str.mid(source, j, 1) == "\t" || str.mid(source, j, 1) == "\r" || str.mid(source, j, 1) == "\n") j++;
            else if (j + 6 <= n && w == "export") { j += 6; }
            else break;
        }
        if (j >= n || str.mid(source, j, 1) != "(") continue;
        var parenEnd = __fec_balanced_end(source, j, "(", ")", mask);
        if (parenEnd < 0) continue;
        j = parenEnd + 1;
        while (j < n && (str.mid(source, j, 1) == " " || str.mid(source, j, 1) == "\t" || str.mid(source, j, 1) == "\r" || str.mid(source, j, 1) == "\n")) j++;
        if (j >= n || str.mid(source, j, 1) != "{") continue;
        var braceClose = __fec_balanced_end(source, j, "{", "}", mask);
        if (braceClose < 0) continue;
        found.push(#{
            "name":       nm.name,
            "start":      pi,
            "bodyStart":  j + 1,
            "bodyClose":  braceClose,
            "end":        braceClose + 1
        });
    }
    return found;
}

function __fec_require_unique(source, name) {
    var all = __fec_find_all(source);
    var matches = #[];
    for (var k = 0; k < all.size(); k++) {
        if (all[k].name == name) matches.push(all[k]);
    }
    if (matches.size() == 0)
        throw "funcedit: функция '" + name + "' не найдена";
    if (matches.size() > 1) {
        var offs = #[];
        for (var m = 0; m < matches.size(); m++) offs.push(matches[m].start);
        throw "funcedit: функция '" + name + "' найдена " + str.toString(matches.size()) +
              " раз (смещения " + json.stringify(offs) + "); используйте уникальное имя";
    }
    return matches[0];
}

funcedit.find = function(source, name) { return __fec_require_unique(source, name); };
funcedit.exists = function(source, name) {
    var all = __fec_find_all(source);
    for (var k = 0; k < all.size(); k++) if (all[k].name == name) return 1;
    return 0;
};
funcedit.isUnique = function(source, name) {
    var all = __fec_find_all(source);
    var cnt = 0;
    for (var k = 0; k < all.size(); k++) if (all[k].name == name) cnt++;
    return cnt == 1;
};

funcedit.getBody = function(source, name) {
    var f = __fec_require_unique(source, name);
    return str.mid(source, f.bodyStart, f.bodyClose - f.bodyStart);
};

funcedit.replaceBody = function(source, name, newBody) {
    var f = __fec_require_unique(source, name);
    return str.mid(source, 0, f.bodyStart) + newBody + str.mid(source, f.bodyClose);
};

funcedit.replace = function(source, name, newFuncSource) {
    var f = __fec_require_unique(source, name);
    return str.mid(source, 0, f.start) + newFuncSource + str.mid(source, f.end);
};

funcedit.insertBefore = function(source, name, snippet) {
    var f = __fec_require_unique(source, name);
    return str.mid(source, 0, f.start) + snippet + "\n" + str.mid(source, f.start);
};

funcedit.insertAfter = function(source, name, snippet) {
    var f = __fec_require_unique(source, name);
    return str.mid(source, 0, f.end) + "\n" + snippet + str.mid(source, f.end);
};

funcedit.balanced = function(source) {
    var n = str.len(source);
    var mask = __fec_mask(source);
    var stack = #[];
    for (var i = 0; i < n; i++) {
        if (mask[i] != 1) continue;
        var c = str.mid(source, i, 1);
        if (c == "(" || c == "[" || c == "{") { stack.push(c); continue; }
        if (c == ")" || c == "]" || c == "}") {
            if (stack.size() == 0) return 0;
            var top = stack.pop();
            var exp = (top == "(") ? ")" : (top == "[") ? "]" : "}";
            if (exp != c) return 0;
        }
    }
    return stack.size() == 0;
};
