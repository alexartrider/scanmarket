// cli.prg — удобный разбор командной строки для утилит Script/Qode.
//
// Подключение (loadModule оставляет модуль в Script::Modules):
//   loadModule(file.normalize(file.join(file.dirname(system.getcommandline().app), "..", "scriptlib", "cli.prg")));
//
// API (namespace cli):
//   cli.parse(schema, [cmdline])  — разбор по схеме → #{"opts", "args", "help"}
//   cli.help(schema)              — текст справки, сгенерированный из той же схемы
//
// cli.parse использует РЕЗУЛЬТАТ system.getcommandline() (ключ "parsed" —
// упорядоченные токены: flag/pos/end), а не перечитывает командную строку.
// Второй аргумент cmdline позволяет передать результат getcommandline()
// вручную (удобно для тестов); по умолчанию вызывается system.getcommandline().
// Первый токен parsed — путь к скрипту (соглашение qodeqt: args.at(1)) — пропускается.
//
// Схема — кортеж:
//   #{
//       "program":    "имя утилиты",                  // для шапки справки (по умолчанию "qodeqt")
//       "usage":      "краткая строка",               // опционально, дописывается в шапку
//       "positional": "FILE [FILE...]",               // описание позиционных для справки
//       "params": #[                                 // массив параметров
//           #{
//               "name":     "output",                 // длинное имя БЕЗ "--"
//               "short":    "o",                      // опционально короткое имя БЕЗ "-"
//               "type":     "string"|"int"|"float"|"bool",  // по умолчанию "string"
//               "default":  "out.txt",                // значение по умолчанию
//               "required": 1,                        // обязательный параметр
//               "repeat":   "last"|"error"|"first",   // политика повторов (по умолчанию "last")
//               "help":     "куда писать результат"   // текст для cli.help()
//           }, ...
//       ]
//   }
//
// Возвращаемое значение cli.parse:
//   opts  — кортеж значений параметров (ключ = name из схемы),
//   args  — массив позиционных аргументов,
//   help  — 1, если был --help/-h (и схема не объявляет свои "help"/"h").
//
// Ошибки разбора (неизвестный параметр, неполный/повторный/некорректное
// значение) — исключение с понятным сообщением; файлы не создаются и не меняются.
//
// Ограничения (сознательные, задокументированы):
//   - короткие флаги разбираются как группа булевых ("-abc" = -a -b -c);
//     значение для короткого флага — ТОЛЬКО отдельным следующим аргументом
//     ("-o value"); форма "-o=value" не поддержана;
//   - значение для длинного флага — либо "--name=value", либо "--name value"
//     (отдельный аргумент); если следующим идёт флаг или "--" — ошибка;
//   - повтор параметра по умолчанию: последнее значение побеждает (как в
//     argparse); можно задать "repeat": "error" или "first" у конкретного параметра;
//   - типизированная проверка: int/float проверяются посимвольной маской
//     (пределы возможностей Script), bool принимает true/false/1/0/yes/no/on/off;
//   - поле параметра, совпадающее со встроенным методом tuple (size, has, get,
//     set, remove, keys, values, contains), недоступно через opts.имя — это
//     ограничение языка (см. language.html).

var cli = #tuple{};

// Поиск описания параметра по имени флага (длинному или короткому).
function __cli_find_spec(schema, flagName) {
    var params = schema.params;
    if (params == null) return null;
    for (var i = 0; i < params.size(); i++) {
        var sp = params[i];
        if (str.toString(sp.name) == flagName) return sp;
        if (sp.short != null && str.toString(sp.short) == flagName) return sp;
    }
    return null;
}

// Целое ли число (маска [+-]? цифры).
function __cli_is_int(s) {
    var n = str.len(s);
    if (n == 0) return 0;
    var i = 0;
    var c0 = str.mid(s, 0, 1);
    if (c0 == "-" || c0 == "+") { i = 1; if (n == 1) return 0; }
    for (; i < n; i++) {
        var c = str.mid(s, i, 1);
        if (c < "0" || c > "9") return 0;
    }
    return 1;
}

// Число ли с плавающей точкой (маска [+-]? digits [.digits] [e[+-]digits]).
function __cli_is_float(s) {
    if (__cli_is_int(s)) return 1;
    var low = str.lower(s);
    var n = str.len(low);
    if (n == 0) return 0;
    var i = 0;
    var c0 = str.mid(low, 0, 1);
    if (c0 == "-" || c0 == "+") { i = 1; if (n == 1) return 0; }
    var digits = 0, dot = 0, exp = 0;
    for (; i < n; i++) {
        var c = str.mid(low, i, 1);
        if (c >= "0" && c <= "9") { digits = 1; continue; }
        if (c == ".") {
            if (dot || exp) return 0;
            dot = 1;
            continue;
        }
        if (c == "e") {
            if (exp || !digits) return 0;
            exp = 1;
            digits = 0;   // после "e" нужны цифры
            if (i + 1 < n) {
                var nxt = str.mid(low, i + 1, 1);
                if (nxt == "-" || nxt == "+") i++;
            }
            continue;
        }
        return 0;
    }
    return digits == 1;
}

// Булево значение из строки (true/false/1/0/yes/no/on/off, регистр не важен).
function __cli_to_bool(s, flagName) {
    var low = str.lower(s);
    if (low == "true" || low == "1" || low == "yes" || low == "on") return 1;
    if (low == "false" || low == "0" || low == "no" || low == "off") return 0;
    throw "cli: параметр '--" + flagName + "' — некорректное булево значение '" + s + "'";
}

// Приведение значения по типу параметра (строка из "=" или отдельного аргумента).
function __cli_coerce(spec, rawVal) {
    var typ = (spec.type == null) ? "string" : str.toString(spec.type);
    var key = str.toString(spec.name);
    if (typ == "bool") return __cli_to_bool(rawVal, key);
    if (typ == "int") {
        if (!__cli_is_int(rawVal))
            throw "cli: параметр '--" + key + "' ожидает целое число, получено '" + rawVal + "'";
        return str.toInt(rawVal);
    }
    if (typ == "float") {
        if (!__cli_is_float(rawVal))
            throw "cli: параметр '--" + key + "' ожидает число, получено '" + rawVal + "'";
        return str.toDouble(rawVal);
    }
    return str.toString(rawVal);   // "string" и всё прочее
}

// Разбор списка токенов parsed (без первого — пути к скрипту).
function __cli_parse_tokens(schema, parsed) {
    var opts = #tuple{};
    var args = #[];
    var help = 0;
    var seen = #tuple{};

    var i = 1;   // 0 — путь к скрипту (соглашение qodeqt)
    while (i < parsed.size()) {
        var t = parsed[i];
        if (t.has("end")) {
            // "--": всё дальше — позиционное
            i++;
            while (i < parsed.size()) { args.push(str.toString(parsed[i].pos)); i++; }
            break;
        }
        if (t.has("flag")) {
            var fname = str.toString(t.flag);
            var spec = __cli_find_spec(schema, fname);
            if (spec == null) {
                // --help / -h обрабатываются, только если схема не объявляет их сама
                if (fname == "help" || fname == "h") { help = 1; i++; continue; }
                throw "cli: неизвестный параметр '--" + fname + "'";
            }
            var key = str.toString(spec.name);
            var typ = (spec.type == null) ? "string" : str.toString(spec.type);
            var inline = t.has("value") ? 1 : 0;

            // Политика повторов (по умолчанию "last" — последнее значение побеждает)
            if (seen.has(key)) {
                var policy = (spec.repeat == null) ? "last" : str.toString(spec.repeat);
                if (policy == "error")
                    throw "cli: параметр '--" + key + "' указан повторно";
                if (policy == "first") {
                    // не перезаписываем; но значение отдельным аргументом нужно пропустить
                    if (!inline && typ != "bool") i += 2; else i++;
                    continue;
                }
                // policy == "last": продолжаем обработку, значение перезапишется
            }
            seen.set(key, 1);

            if (typ == "bool") {
                var b = 1;
                if (inline) b = __cli_to_bool(str.toString(t.value), key);
                opts.set(key, b);
                i++;
            } else {
                var val = null;
                if (inline) {
                    val = str.toString(t.value);
                    i++;
                } else {
                    // значение отдельным следующим аргументом
                    var nxt = (i + 1 < parsed.size()) ? parsed[i + 1] : null;
                    if (nxt == null || nxt.has("flag") || nxt.has("end"))
                        throw "cli: параметр '--" + key + "' требует значение";
                    val = str.toString(nxt.pos);
                    i += 2;
                }
                opts.set(key, __cli_coerce(spec, val));
            }
            continue;
        }
        if (t.has("pos")) { args.push(str.toString(t.pos)); i++; continue; }
        i++;   // неизвестный тип токена — пропускаем
    }

    // Проверка обязательных параметров
    var params = schema.params;
    if (params != null) {
        for (var k = 0; k < params.size(); k++) {
            var sp = params[k];
            var kk = str.toString(sp.name);
            if (sp.required && !opts.has(kk))
                throw "cli: обязательный параметр '--" + kk + "' не задан";
        }
    }

    // Значения по умолчанию (после проверки обязательных, чтобы required не был "скрыт" дефолтом)
    if (params != null) {
        for (var d = 0; d < params.size(); d++) {
            var dp = params[d];
            var dk = str.toString(dp.name);
            if (!opts.has(dk) && dp["default"] != null)
                opts.set(dk, __cli_coerce(dp, str.toString(dp["default"])));
        }
    }

    return #{"opts": opts, "args": args, "help": help};
}

cli.parse = function(schema, cmdline) {
    if (schema == null || !schema.has("params"))
        throw "cli: некорректная схема — нужен кортеж с ключом 'params' (массив описаний)";
    var cc = (cmdline == null) ? system.getcommandline() : cmdline;
    if (!cc.has("parsed"))
        throw "cli: system.getcommandline() не вернул 'parsed' — требуется свежая сборка qodeqt";
    return __cli_parse_tokens(schema, cc.parsed);
};

// Справка, сгенерированная из схемы (используется и для --help, и по требованию).
cli.help = function(schema) {
    var out = #[];
    var prog = (schema.program == null) ? "qodeqt" : str.toString(schema.program);
    var usage = (schema.usage == null) ? "" : " " + str.toString(schema.usage);
    out.push("Использование: " + prog + " [параметры]" + usage);
    out.push("");
    out.push("Параметры:");
    var params = (schema.params == null) ? #[] : schema.params;
    if (params.size() == 0) out.push("  (нет)");
    for (var i = 0; i < params.size(); i++) {
        var sp = params[i];
        var left = "";
        if (sp.short != null) left += "-" + str.toString(sp.short) + ", ";
        left += "--" + str.toString(sp.name);
        var typ = (sp.type == null) ? "string" : str.toString(sp.type);
        if (typ != "bool") left += " <" + typ + ">";
        var tail = "";
        if (sp.required) tail += " [обязательный]";
        if (sp["default"] != null) tail += " [по умолчанию " + str.toString(sp["default"]) + "]";
        var hlp = (sp.help == null) ? "" : str.toString(sp.help);
        if (hlp == "") hlp = str.toString(sp.name);
        out.push("  " + left + " — " + hlp + tail);
    }
    if (schema.positional != null) {
        out.push("");
        out.push("Позиционные: " + str.toString(schema.positional));
    }
    out.push("");
    out.push("Справка: --help, -h");
    return str.join("\n", out);
};
