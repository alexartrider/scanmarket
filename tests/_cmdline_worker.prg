// _cmdline_worker.prg — вспомогательный воркер для тестов getcommandline() (qt/test).
//
// Запуск: qodeqt _cmdline_worker.prg <аргументы...> <маркер>
// Маркер — ПОСЛЕДНИЙ позиционный аргумент. В него пишется JSON результата
// system.getcommandline() БЕЗ маркера: из raw/args/parsed убирается последний
// токен (маркер — часть протокола теста, а не тестируемый аргумент), count
// пересчитывается. Возвращает 0 в любом случае (тест судит по файлу-маркеру).
var c = system.getcommandline();
var args = c.args;
var marker = str.toString(args[args.size() - 1]);
var raw = c.raw;
var parsed = c.parsed;
if (args.size() > 0) args.pop();
if (raw.size() > 0) raw.pop();
if (parsed.size() > 0) parsed.pop();
var out = #{
    "app":      c.app,
    "basename": c.basename,
    "dirname":  c.dirname,
    "filename": c.filename,
    "argv0":    c.argv0,
    "raw":      raw,
    "args":     args,
    "count":    args.size(),
    "flags":    c.flags,
    "parsed":   parsed
};
file.writeatom(marker, json.stringify(out), #{"enc": "utf8-nobom"});
return 0;
