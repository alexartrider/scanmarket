// test_jsonedit.prg — библиотека jsonedit.prg: безопасное редактирование JSON
// и Скрипта внутри JSON-форм.
//
// План:
//   1) jsonedit.format/getText/setText — пути вида a.b[0].c, изменение по пути
//      возвращает НОВУЮ строку, исходник не мутируется, корректная работа
//      с битым JSON;
//   2) jsonedit.validateForm — валидная/невалидные RuntimeForm
//      (возвращает #{"ok","errors"}), битый JSON;
//   3) jsonedit.collectEvents/findWidgetPath/handlerFor — мини-форма с виджетами,
//      детект пути по имени (включая детей), отсутствующий виджет -> null.
// Поведение согласовано с json.getPath/json.setPath/json.validateStructure
// (см. qt/sample/test_json_path.prg).
loadModule(file.join(file.dirname(system.getcommandline().args[0]), "..", "scriptlib", "qtestlib.prg"));
loadModule(file.join(file.dirname(system.getcommandline().args[0]), "..", "scriptlib", "jsonedit.prg"));

// ── данные ────────────────────────────────────────────────────────────────────
var compact = json.stringify(#{"a": #{"b": #[#{"c": 1}]}});
var broken  = "{не json}";
var broken2 = "{\"a\": 1,\n\"b\": oops}";

qt_group("jsonedit.format");
var pretty4 = jsonedit.format(compact);
qt_ok("format: содержит переносы (pretty)", str.count(pretty4, "\n") >= 2);
qt_ok("format: отступ 4 пробела", str.pos(pretty4, "\n    \"a\"") >= 0);
qt_ok("format: обратим — getPath по путю работает", json.getPath(json.parse(pretty4), "a.b[0].c") == 1);
var pretty2 = jsonedit.format(compact, 2);
qt_ok("format(indent=2): отступ 2 пробела", str.pos(pretty2, "\n  \"a\"") >= 0);
qt_ok("format(indent=2) отличается от indent=4", pretty2 != pretty4);
qt_check("format: битый JSON -> \"null\" (json.parse даёт null)", jsonedit.format(broken), "null");

qt_group("jsonedit.getText");
qt_check("getText по пути a.b[0].c", jsonedit.getText(compact, "a.b[0].c"), 1);
qt_check("getText: отсутствующий ключ -> default", jsonedit.getText(compact, "a.b[0].x", "DEF"), "DEF");
qt_check("getText: отсутствующий ключ без default -> null", jsonedit.getText(compact, "a.b[0].x"), null);
qt_ok("getText согласован с json.getPath", jsonedit.getText(compact, "a.b[0].c") == json.getPath(json.parse(compact), "a.b[0].c"));
qt_throws("getText: битый JSON -> исключение",
          function() { jsonedit.getText(broken, "a.b", "DEF"); }, "expected object");

qt_group("jsonedit.setText");
var edited = jsonedit.setText(compact, "a.b[0].c", 99);
qt_check("setText: новое значение по пути", jsonedit.getText(edited, "a.b[0].c"), 99);
qt_check("setText: вернул НОВУЮ строку (не ту же)", edited != compact, 1);
qt_ok("setText: результат pretty (переносы)", str.count(edited, "\n") >= 2);
qt_check("setText: исходник не мутируется (c всё ещё 1)", jsonedit.getText(compact, "a.b[0].c"), 1);
qt_check("setText: добавление нового ключа", jsonedit.getText(jsonedit.setText(compact, "a.d", "новый"), "a.d"), "новый");
qt_ok("setText согласован с json.setPath",
      jsonedit.setText(compact, "a.b[0].c", 99) ==
      json.stringify(json.setPath(json.parse(compact), "a.b[0].c", 99), true, 4));
qt_throws("setText: битый JSON -> исключение",
          function() { jsonedit.setText(broken, "a.b", 1); }, "must be an object");

qt_group("jsonedit.validateForm");
function vRes(jsonText) {
    var v = jsonedit.validateForm(jsonText);
    return #{"ok": v.ok, "errors": v.errors};
}
var validForm = json.stringify(#{
    "code": #{"text": "function f() {}"},
    "form": #{
        "formProperties": #{"objectName": "F", "events": #{"formCreate": "fc"}},
        "widgets": #[
            #{"class": "QPushButton", "name": "b1", "events": #{"clicked": "h1"}}
        ]
    }
});
var vv = vRes(validForm);
qt_check("валидная форма: ok==true", vv.ok, true);
qt_checkJson("валидная форма: errors пуст", vv.errors, #[]);
qt_ok("validateForm возвращает #{\"ok\",\"errors\"}", jsonedit.validateForm(validForm).has("ok") && jsonedit.validateForm(validForm).has("errors"));
var vm = vRes(json.stringify(#{"code": #{"text": "x"}, "form": #{"formProperties": #{"objectName": "Min"}}}));
qt_check("минимальная непустая форма: ok==true", vm.ok, true);
var vNoCode = vRes(json.stringify(#{"form": #{"formProperties": #{"objectName": "F"}}}));
qt_check("нет code: ok==false", vNoCode.ok, false);
qt_ok("нет code: сообщение об отсутствующем поле", str.pos(vNoCode.errors[0], "code: required field missing") >= 0);
var vCodeStr = vRes(json.stringify(#{"code": "x", "form": #{"formProperties": #{"objectName": "F"}}}));
qt_check("code не tuple: ok==false", vCodeStr.ok, false);
qt_ok("code не tuple: сообщение о типе", str.pos(vCodeStr.errors[0], "code: expected tuple") >= 0);
var vCodeBad = vRes(json.stringify(#{"code": #{"text": 42}, "form": #{"formProperties": #{"objectName": "F"}}}));
qt_check("code.text не строка: ok==false", vCodeBad.ok, false);
qt_ok("code.text не строка: сообщение о типе", str.pos(vCodeBad.errors[0], "expected string") >= 0);
var vNoForm = vRes(json.stringify(#{"code": #{"text": "x"}}));
qt_check("нет form: ok==false", vNoForm.ok, false);
qt_ok("нет form: сообщение об отсутствующем поле", str.pos(vNoForm.errors[0], "form: required field missing") >= 0);
var vBadW = vRes(json.stringify(#{"code": #{"text": "x"}, "form": #{"formProperties": #{"objectName": "F"}, "widgets": #{"not": "array"}}}));
qt_check("widgets не массив: ok==false", vBadW.ok, false);
qt_ok("widgets не массив: сообщение о типе", str.pos(vBadW.errors[0], "widgets: expected array") >= 0);
var vBroken = vRes(broken2);
qt_check("битый JSON: ok==false", vBroken.ok, false);
qt_ok("битый JSON: понятное сообщение", str.pos(vBroken.errors[0], "не удалось разобрать JSON") >= 0);

qt_group("jsonedit.collectEvents / findWidgetPath / handlerFor");
var miniForm = json.stringify(#{
    "code": #{"text": "x"},
    "form": #{
        "formProperties": #{"events": #{"formCreate": "formCreate"}},
        "widgets": #[
            #{"class": "QPushButton", "name": "btnSave", "events": #{"clicked": "onSave"}},
            #{"class": "QGroupBox", "name": "box", "children": #[
                #{"class": "QLineEdit", "name": "editName", "events": #{"textChanged": "onEdit"}}
            ]},
            #{"class": "QLabel", "name": "plain"}
        ]
    }
});
var evts = jsonedit.collectEvents(miniForm);
qt_check("collectEvents: собраны все события (3)", evts.size(), 3);
qt_checkJson("collectEvents: событие формы", evts[0], #{"entity": "form", "event": "formCreate", "handler": "formCreate"});
qt_ok("collectEvents: событие виджета верхнего уровня",
      evts[1].entity == "btnSave" && evts[1].event == "clicked" && evts[1].handler == "onSave");
qt_ok("collectEvents: событие вложенного виджета (children)",
      evts[2].entity == "editName" && evts[2].event == "textChanged" && evts[2].handler == "onEdit");

qt_check("findWidgetPath: виджет верхнего уровня", jsonedit.findWidgetPath(miniForm, "btnSave"), "form.widgets[0]");
qt_check("findWidgetPath: вложенный виджет", jsonedit.findWidgetPath(miniForm, "editName"), "form.widgets[1].children[0]");
qt_check("findWidgetPath: отсутствующий виджет -> null", jsonedit.findWidgetPath(miniForm, "noSuchWidget"), null);
qt_check("findWidgetPath: форма без widgets -> null", jsonedit.findWidgetPath(json.stringify(#{"code": #{"text": "x"}, "form": #{"formProperties": #{"objectName": "F"}}}), "x"), null);

var savePath = jsonedit.findWidgetPath(miniForm, "btnSave");
qt_check("handlerFor: обработчик виджета", jsonedit.handlerFor(miniForm, savePath, "clicked"), "onSave");
qt_check("handlerFor: обработчик формы", jsonedit.handlerFor(miniForm, "form.formProperties", "formCreate"), "formCreate");
qt_check("handlerFor: отсутствующее событие -> null", jsonedit.handlerFor(miniForm, savePath, "hover"), null);
qt_check("handlerFor: отсутствующий узел -> null", jsonedit.handlerFor(miniForm, "form.widgets[5]", "clicked"), null);
qt_check("handlerFor: узел без events -> null", jsonedit.handlerFor(miniForm, "form.widgets[2]", "clicked"), null);

var rc = qt_done();
return rc;
