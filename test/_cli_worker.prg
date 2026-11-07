// _cli_worker.prg — вспомогательный воркер для тестов cli.prg (qt/test).
//
// Запуск: qodeqt _cli_worker.prg <аргументы...> <маркер>
// Маркер — ПОСЛЕДНИЙ позиционный аргумент. В него пишется JSON:
//   #{"opts": ..., "args": ..., "help": 0|1, "helpText": ..., "error": ...}
// При ошибке разбора cli.parse — поле "error" с текстом исключения.
// Возвращает 0 в любом случае (тест судит по файлу-маркеру).
loadModule(file.join(file.dirname(system.getcommandline().args[0]), "..", "scriptlib", "cli.prg"));

var schema = #{
    "program":    "cli_worker",
    "usage":      "[опции] FILE",
    "positional": "FILE — входной файл",
    "params": #[
        #{"name": "output", "short": "o", "type": "string", "default": "out.txt", "help": "файл результата"},
        #{"name": "verbose", "short": "v", "type": "bool", "help": "подробный вывод"},
        #{"name": "count",   "type": "int", "help": "сколько раз"},
        #{"name": "ratio",   "type": "float", "default": 1.5, "help": "коэффициент"},
        #{"name": "name",    "type": "string", "help": "имя"},
        #{"name": "uniq",    "type": "string", "repeat": "error", "help": "нельзя повторять"},
        #{"name": "mode",    "type": "string", "help": "режим работы"}
    ]
};

var c = system.getcommandline();
var marker = str.toString(c.args[c.args.size() - 1]);
try {
    var r = cli.parse(schema);
    var out = #{"opts": r.opts, "args": r.args, "help": r.help, "error": ""};
    if (r.help) out.helpText = cli.help(schema);
    // убрать маркер (последний позиционный аргумент) из отчёта об args
    if (out.args.size() > 0) out.args.pop();
    file.writeatom(marker, json.stringify(out), #{"enc": "utf8-nobom"});
} catch (e) {
    file.writeatom(marker, json.stringify(#{"error": str.toString(e)}), #{"enc": "utf8-nobom"});
}
return 0;
