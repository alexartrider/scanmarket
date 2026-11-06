// jsonedit.prg — утилиты безопасного редактирования JSON и Скрипта внутри JSON-форм.
//
// Подключение (loadModule оставляет функции в Script::Modules):
//   loadModule(file.normalize(file.join(file.dirname(system.getcommandline().app), "..", "scriptlib", "jsonedit.prg")));
//
// API (namespace jsonedit):
//   jsonedit.format(jsonText, [indent])        — переформатировать JSON (по умолчанию 4 пробела)
//   jsonedit.getText(jsonText, path, [def])    — текст по пути из строки JSON
//   jsonedit.setText(jsonText, path, value, [indent]) — строка JSON после изменения по пути
//   jsonedit.validateForm(jsonText)            — проверка структуры RuntimeForm → #{"ok","errors"}
//   jsonedit.collectEvents(jsonText)           — все события формы/виджетов → массив #{"entity","event","handler"}
//   jsonedit.findWidgetPath(jsonText, name)    — путь к виджету по имени или null
//   jsonedit.handlerFor(jsonText, entityPath, event) — имя обработчика для события
//
// Значения JSON-объектов представлены как tuple (#{}), массивы — array (#[]).
// Изменения возвращают НОВУЮ JSON-строку; исходный объект не мутируется.

var jsonedit = #tuple{};

jsonedit.format = function(jsonText, indent) {
    var obj = json.parse(jsonText);
    return json.stringify(obj, true, (indent == null) ? 4 : indent);
};

jsonedit.getText = function(jsonText, path, def) {
    var obj = json.parse(jsonText);
    return json.getPath(obj, path, def);
};

jsonedit.setText = function(jsonText, path, value, indent) {
    var obj = json.parse(jsonText);
    var root = json.setPath(obj, path, value);
    return json.stringify(root, true, (indent == null) ? 4 : indent);
};

jsonedit.validateForm = function(jsonText) {
    var obj = json.parse(jsonText);
    if (obj == null) return #{"ok": 0, "errors": #[ "не удалось разобрать JSON" ]};
    var v = json.validateStructure(obj, #{"code": "tuple", "form": "tuple"});
    if (!v.ok) return v;
    var vc = json.validateStructure(obj.code, #{"text": "string"});
    if (!vc.ok) return #{"ok": 0, "errors": vc.errors};
    var vf = json.validateStructure(obj.form, #{
        "formProperties?": "tuple",
        "widgets?":        "array",
        "menuBar?":        "array",
        "toolBar?":        "tuple",
        "statusBar?":      "tuple"
    });
    return vf;
};

// путь к виджету по имени ("form.widgets[i]"; children раскрывают на отдельные элементы)
function __jec_findWidgetPath(nodeList, basePath, widgetName) {
    for (var ix = 0; ix < nodeList.size(); ix++) {
        var childObj = nodeList[ix];
        var p = basePath + "[" + ix + "]";
        if (childObj.name == widgetName) return p;
        if (childObj.children != null) {
            var sub = __jec_findWidgetPath(childObj.children, p + ".children", widgetName);
            if (sub != null) return sub;
        }
    }
    return null;
}

jsonedit.findWidgetPath = function(jsonText, widgetName) {
    var obj = json.parse(jsonText);
    if (obj.form == null || obj.form.widgets == null) return null;
    return __jec_findWidgetPath(obj.form.widgets, "form.widgets", widgetName);
};

jsonedit.handlerFor = function(jsonText, entityPath, event) {
    var obj = json.parse(jsonText);
    var node = json.getPath(obj, entityPath, null);
    if (node == null || node.events == null) return null;
    return node.events[event];
};

// Все события: "#{entity: "form"/путь виджета, event, handler}"
function __jec_collectWidgetEvents(nodeList) {
    var acc = #[];
    for (var ix = 0; ix < nodeList.size(); ix++) {
        var wItem = nodeList[ix];
        if (wItem.name != null && wItem.events != null) {
            var namesArr = propertyNames(wItem.events);
            for (var kk = 0; kk < namesArr.size(); kk++) {
                var evKey = namesArr[kk];
                acc.push(#{"entity": wItem.name, "event": evKey, "handler": wItem.events[evKey]});
            }
        }
        if (wItem.children != null) {
            var sub = __jec_collectWidgetEvents(wItem.children);
            for (var mm = 0; mm < sub.size(); mm++) acc.push(sub[mm]);
        }
    }
    return acc;
}

jsonedit.collectEvents = function(jsonText) {
    var obj = json.parse(jsonText);
    var out = #[];
    if (obj.form == null) return out;
    var fp = obj.form.formProperties;
    if (fp != null && fp.events != null) {
        var names = propertyNames(fp.events);
        for (var k = 0; k < names.size(); k++) {
            var ev = names[k];
            out.push(#{"entity": "form", "event": ev, "handler": fp.events[ev]});
        }
    }
    if (obj.form.widgets != null) {
        var sub = __jec_collectWidgetEvents(obj.form.widgets);
        for (var mm = 0; mm < sub.size(); mm++) out.push(sub[mm]);
    }
    return out;
};