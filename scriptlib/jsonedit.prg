// jsonedit.prg — утилиты безопасного редактирования JSON и Скрипта внутри JSON-форм.
//
// Подключение (loadModule оставляет функции в Script::Modules):
//   loadModule(file.normalize(file.join(file.dirname(system.getcommandline().app), "..", "scriptlib", "jsonedit.prg")));
//
// API (namespace jsonedit):
//   jsonedit.format(jsonText, [indent])        — переформатировать JSON (по умолчанию 4 пробела)
//   jsonedit.getText(jsonText, path, [def])    — текст по пути из строки JSON
//   jsonedit.setText(jsonText, path, value, [indent]) — строка JSON после изменения по пути
//   jsonedit.validateForm(jsonText)            — проверка структуры ресурса и QRXL
//   jsonedit.inspect(jsonText)                 — компактная сводка формы и таблиц
//   jsonedit.setWidgetProperty(jsonText, name, property, value)
//   jsonedit.setWidgetEvent/renameWidget(jsonText, name, ...)
//   jsonedit.renameTable / resizeTable / getCell / setCell — row/col 0-based
//   jsonedit.collectEvents(jsonText)           — события формы/виджетов/меню
//   jsonedit.findWidgetPath(jsonText, name)    — путь к виджету по имени или null
//   jsonedit.handlerFor(jsonText, entityPath, event) — имя обработчика для события
//
// Значения JSON-объектов представлены как tuple (#{}), массивы — array (#[]).
// Изменения возвращают НОВУЮ JSON-строку; исходный объект не мутируется.

var jsonedit = #tuple{};

jsonedit.format = function(jsonText, indent) {
    return json.formatText(jsonText, (indent == null) ? 4 : indent);
};

jsonedit.getText = function(jsonText, path, def) {
    var raw = json.getText(jsonText, path);
    var parsedSource = json.parseEx(jsonText);
    if (!parsedSource.ok || !json.hasPath(parsedSource.value, path)) return def;
    var parsed = json.parseEx(raw);
    return parsed.ok ? parsed.value : def;
};

jsonedit.setText = function(jsonText, path, value, indent) {
    var current = json.getText(jsonText, path);
    var replacement = json.stringify(value);
    // При изменении уже boolean-поля сохраняем его JSON-тип. Явный переход
    // boolean -> number делается через setTextRaw.
    if (current == "true" || current == "false") replacement = json.stringifyBool(value);
    return json.replaceText(jsonText, path, replacement, true, (indent == null) ? 4 : indent);
};

// Явное JSON-значение для случаев, когда нужен настоящий true/false, null,
// массив или объект без потери JSON-типа на границе ScriptValue.
jsonedit.setTextRaw = function(jsonText, path, replacementJsonText, indent) {
    return json.replaceText(jsonText, path, replacementJsonText, true, (indent == null) ? 4 : indent);
};

jsonedit.setBool = function(jsonText, path, value, indent) {
    return json.replaceText(jsonText, path, json.stringifyBool(value), true, (indent == null) ? 4 : indent);
};

jsonedit.validateForm = function(jsonText) {
    var parsed = json.parseEx(jsonText);
    if (!parsed.ok) return #{"ok": 0, "errors": #["JSON: " + parsed.error.message + " (" + str.toString(parsed.error.line) + ":" + str.toString(parsed.error.column) + ")"]};
    var obj = parsed.value;
    var errors = #[];
    if (typeName(obj) != "tuple") errors.push("$: ожидался объект ресурса");
    else {
        if (obj.code == null || typeName(obj.code) != "tuple") errors.push("code: обязательный объект");
        else if (obj.code.text == null || typeName(obj.code.text) != "string") errors.push("code.text: обязательная строка");
        if (obj.form == null || typeName(obj.form) != "tuple") errors.push("form: обязательный объект");
        else errors = __jec_validateForm(obj.form, errors);
        if (obj.info != null && typeName(obj.info) != "tuple") errors.push("info: ожидался объект");
        if (obj.info != null && obj.info.param != null && typeName(obj.info.param) != "string") errors.push("info.param: ожидалась строка");
        if (obj.rxl != null) errors = __jec_validateRxl(obj.rxl, errors);
    }
    return #{"ok": (errors.size() == 0), "errors": errors};
};

function __jec_validateEvents(events, path, errors) {
    if (events == null) return errors;
    if (typeName(events) != "tuple") { errors.push(path + ".events: ожидался объект"); return errors; }
    var keys = propertyNames(events);
    for (var i = 0; i < keys.size(); i++)
        if (typeName(events[keys[i]]) != "string") errors.push(path + ".events." + keys[i] + ": ожидалось имя обработчика-строка");
    return errors;
}

function __jec_hasKey(obj, key) {
    if (typeName(obj) != "tuple") return false;
    var keys = propertyNames(obj);
    for (var i = 0; i < keys.size(); i++) if (keys[i] == key) return true;
    return false;
}

function __jec_validateWidgetList(list, base, errors, names) {
    if (typeName(list) != "array") { errors.push(base + ": ожидался массив"); return #{"errors": errors, "names": names}; }
    for (var i = 0; i < list.size(); i++) {
        var p = base + "[" + str.toString(i) + "]";
        var w = list[i];
        if (typeName(w) != "tuple") { errors.push(p + ": ожидался объект виджета"); continue; }
        if (typeName(w["class"]) != "string" || w["class"] == "") errors.push(p + ".class: обязательное имя Qt-класса");
        if (typeName(w.name) != "string" || w.name == "") errors.push(p + ".name: обязательное имя виджета");
        else {
            for (var j = 0; j < names.size(); j++) if (names[j] == w.name) errors.push(p + ".name: повтор имени '" + w.name + "'");
            names.push(w.name);
        }
        if (w.geometry != null) {
            if (typeName(w.geometry) != "tuple") errors.push(p + ".geometry: ожидался объект");
            else {
                var gkeys = #["x", "y", "w", "h"];
                for (var gi = 0; gi < gkeys.size(); gi++)
                    if (w.geometry[gkeys[gi]] != null && typeName(w.geometry[gkeys[gi]]) != "int") errors.push(p + ".geometry." + gkeys[gi] + ": ожидалось целое число");
                if (w.geometry.w != null && w.geometry.w <= 0) errors.push(p + ".geometry.w: должно быть > 0");
                if (w.geometry.h != null && w.geometry.h <= 0) errors.push(p + ".geometry.h: должно быть > 0");
            }
        }
        if (w.properties != null && typeName(w.properties) != "tuple") errors.push(p + ".properties: ожидался объект");
        errors = __jec_validateEvents(w.events, p, errors);
        if (w.children != null) {
            var nested = __jec_validateWidgetList(w.children, p + ".children", errors, names);
            errors = nested.errors;
            names = nested.names;
        }
    }
    return #{"errors": errors, "names": names};
}

function __jec_validateActionList(list, base, errors) {
    if (list == null) return errors;
    if (typeName(list) != "array") { errors.push(base + ": ожидался массив"); return errors; }
    for (var i = 0; i < list.size(); i++) {
        var item = list[i];
        var p = base + "[" + str.toString(i) + "]";
        if (typeName(item) != "tuple") { errors.push(p + ": ожидался объект"); continue; }
        if (item.objectName != null && typeName(item.objectName) != "string") errors.push(p + ".objectName: ожидалась строка");
        if (item.title != null && typeName(item.title) != "string") errors.push(p + ".title: ожидалась строка");
        if (item.type != null && typeName(item.type) != "string") errors.push(p + ".type: ожидалась строка");
        errors = __jec_validateEvents(item.events, p, errors);
        if (item.children != null) errors = __jec_validateActionList(item.children, p + ".children", errors);
    }
    return errors;
}

function __jec_validateForm(form, errors) {
    if (form.formProperties != null && typeName(form.formProperties) != "tuple") errors.push("form.formProperties: ожидался объект");
    else if (form.formProperties != null) {
        errors = __jec_validateEvents(form.formProperties.events, "form.formProperties", errors);
        var fp = form.formProperties;
        var intProps = #["width", "height", "minW", "minH", "maxW", "maxH", "windowModality"];
        for (var pi = 0; pi < intProps.size(); pi++)
            if (fp[intProps[pi]] != null && typeName(fp[intProps[pi]]) != "int") errors.push("form.formProperties." + intProps[pi] + ": ожидалось целое число");
        if (fp.objectName != null && typeName(fp.objectName) != "string") errors.push("form.formProperties.objectName: ожидалась строка");
        if (fp.windowTitle != null && typeName(fp.windowTitle) != "string") errors.push("form.formProperties.windowTitle: ожидалась строка");
    }
    if (form.widgets != null) {
        var widgetsRes = __jec_validateWidgetList(form.widgets, "form.widgets", errors, #[]);
        errors = widgetsRes.errors;
    }
    errors = __jec_validateActionList(form.menuBar, "form.menuBar", errors);
    errors = __jec_validateActionList(form.toolBar, "form.toolBar", errors);
    errors = __jec_validateActionList(form.statusBar, "form.statusBar", errors);
    if (form.version != null && typeName(form.version) != "int") errors.push("form.version: ожидалось целое число");
    return errors;
}

function __jec_validateRxl(rxl, errors) {
    if (typeName(rxl) != "array") { errors.push("rxl: ожидался массив"); return errors; }
    var tableNames = #[];
    for (var ti = 0; ti < rxl.size(); ti++) {
        var p = "rxl[" + str.toString(ti) + "]";
        var table = rxl[ti];
        if (typeName(table) != "tuple") { errors.push(p + ": ожидался объект таблицы"); continue; }
        if (typeName(table.name) != "string" || table.name == "") errors.push(p + ".name: обязательное имя таблицы");
        else {
            for (var tn = 0; tn < tableNames.size(); tn++) if (tableNames[tn] == table.name) errors.push(p + ".name: повтор имени таблицы '" + table.name + "'");
            tableNames.push(table.name);
        }
        if (typeName(table.data) != "tuple") { errors.push(p + ".data: обязательный объект"); continue; }
        var d = table.data;
        if (typeName(table.info) != "tuple") errors.push(p + ".info: ожидался объект");
        var numericData = #["defHeight", "defWidth", "fixedHeight", "fixedWidth", "header", "footer", "orientation", "option", "paperSize"];
        for (var di = 0; di < numericData.size(); di++)
            if (d[numericData[di]] != null && typeName(d[numericData[di]]) != "int") errors.push(p + ".data." + numericData[di] + ": ожидалось целое число");
        if (d.margin != null && typeName(d.margin) != "tuple") errors.push(p + ".data.margin: ожидался объект");
        if (d.margin != null && typeName(d.margin) == "tuple") {
            var margins = #["left", "top", "right", "bottom"];
            for (var mi = 0; mi < margins.size(); mi++)
                if (d.margin[margins[mi]] != null && (typeName(d.margin[margins[mi]]) != "int" || d.margin[margins[mi]] < 0)) errors.push(p + ".data.margin." + margins[mi] + ": ожидалось целое >= 0");
        }
        if (__jec_hasKey(d, "fonts") && typeName(d.fonts) != "array") errors.push(p + ".data.fonts: ожидался массив");
        if (__jec_hasKey(d, "styles") && typeName(d.styles) != "array") errors.push(p + ".data.styles: ожидался массив");
        if (__jec_hasKey(d, "widths") && typeName(d.widths) != "array") errors.push(p + ".data.widths: ожидался массив");
        if (__jec_hasKey(d, "heights") && typeName(d.heights) != "array") errors.push(p + ".data.heights: ожидался массив");
        if (__jec_hasKey(d, "namedArea") && typeName(d.namedArea) != "array") errors.push(p + ".data.namedArea: ожидался массив");
        if (__jec_hasKey(d, "objects") && typeName(d.objects) != "array") errors.push(p + ".data.objects: ожидался массив");
        if (__jec_hasKey(d, "pageBreak") && typeName(d.pageBreak) != "tuple") errors.push(p + ".data.pageBreak: ожидался объект");
        if (__jec_hasKey(d, "cells") && typeName(d.cells) != "array") errors.push(p + ".data.cells: ожидался массив строк");
        else if (__jec_hasKey(d, "cells")) {
            for (var r = 0; r < d.cells.size(); r++) {
                if (typeName(d.cells[r]) != "array") { errors.push(p + ".data.cells[" + str.toString(r) + "]: ожидался массив ячеек"); continue; }
                for (var c = 0; c < d.cells[r].size(); c++) {
                    var cell = d.cells[r][c];
                    var cp = p + ".data.cells[" + str.toString(r) + "][" + str.toString(c) + "]";
                    if (typeName(cell) != "tuple") { errors.push(cp + ": ожидался объект ячейки"); continue; }
                    if (cell.size() == 0) continue;
                    if (__jec_hasKey(cell, "t") && typeName(cell.t) != "string") errors.push(cp + ".t: ожидалась строка");
                    if (__jec_hasKey(cell, "f") && (typeName(cell.f) != "int" || cell.f < 0 || !__jec_hasKey(d, "fonts") || typeName(d.fonts) != "array" || cell.f >= d.fonts.size())) errors.push(cp + ".f: некорректный индекс шрифта");
                    if (__jec_hasKey(cell, "s") && (typeName(cell.s) != "int" || cell.s < 0 || !__jec_hasKey(d, "styles") || typeName(d.styles) != "array" || cell.s >= d.styles.size())) errors.push(cp + ".s: некорректный индекс стиля");
                    if (__jec_hasKey(cell, "uc") && typeName(cell.uc) != "int") errors.push(cp + ".uc: ожидалось целое число");
                    if (__jec_hasKey(cell, "ur") && typeName(cell.ur) != "int") errors.push(cp + ".ur: ожидалось целое число");
                    if (__jec_hasKey(cell, "uc") && cell.uc > 0 && c + cell.uc >= d.cells[r].size()) errors.push(cp + ".uc: объединение выходит за ширину строки");
                    if (__jec_hasKey(cell, "ur") && cell.ur > 0 && r + cell.ur >= d.cells.size()) errors.push(cp + ".ur: объединение выходит за число строк");
                    if (__jec_hasKey(cell, "uc") && cell.uc < 0 && c + cell.uc < 0) errors.push(cp + ".uc: ссылка объединённой ячейки выходит за левую границу");
                    if (__jec_hasKey(cell, "ur") && cell.ur < 0 && r + cell.ur < 0) errors.push(cp + ".ur: ссылка объединённой ячейки выходит за верхнюю границу");
                }
            }
        }
        if (__jec_hasKey(d, "namedArea") && typeName(d.namedArea) == "array") for (var ni = 0; ni < d.namedArea.size(); ni++) {
            var area = d.namedArea[ni];
            if (typeName(area) != "tuple" || typeName(area.name) != "string") errors.push(p + ".data.namedArea[" + str.toString(ni) + "]: ожидались name и прямоугольник");
            else if (area.l == null || area.t == null || area.r == null || area.b == null || typeName(area.l) != "int" || typeName(area.t) != "int" || typeName(area.r) != "int" || typeName(area.b) != "int" || area.l < 0 || area.t < 0 || area.r < area.l || area.b < area.t)
                errors.push(p + ".data.namedArea[" + str.toString(ni) + "]: некорректные границы");
        }
        if (__jec_hasKey(d, "objects") && typeName(d.objects) == "array") for (var oi = 0; oi < d.objects.size(); oi++) {
            var object = d.objects[oi];
            var op = p + ".data.objects[" + str.toString(oi) + "]";
            if (typeName(object) != "tuple") errors.push(op + ": ожидался объект");
            else {
                if (object.options == null || typeName(object.options) != "tuple") errors.push(op + ".options: обязательный объект");
                else {
                    var opt = object.options;
                    var coords = #["r1", "c1", "r2", "c2"];
                    for (var ci = 0; ci < coords.size(); ci++) if (opt[coords[ci]] != null && (typeName(opt[coords[ci]]) != "int" || opt[coords[ci]] < 0)) errors.push(op + ".options." + coords[ci] + ": координата должна быть целым >= 0");
                }
                if (object.text != null && typeName(object.text) != "string") errors.push(op + ".text: ожидалась строка");
            }
        }
    }
    return errors;
}

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
    var paths = __jec_findWidgetPaths(obj.form.widgets, "form.widgets", widgetName, #[]);
    if (paths.size() > 1) throw "jsonedit.findWidgetPath: неоднозначное имя виджета '" + widgetName + "' (совпадений: " + str.toString(paths.size()) + ")";
    return paths.size() == 0 ? null : paths[0];
};

function __jec_findWidgetPaths(nodeList, basePath, widgetName, paths) {
    for (var ix = 0; ix < nodeList.size(); ix++) {
        var node = nodeList[ix];
        var p = basePath + "[" + str.toString(ix) + "]";
        if (node.name == widgetName) paths.push(p);
        if (node.children != null && typeName(node.children) == "array")
            paths = __jec_findWidgetPaths(node.children, p + ".children", widgetName, paths);
    }
    return paths;
}

jsonedit.handlerFor = function(jsonText, entityPath, event) {
    var obj = json.parse(jsonText);
    var node = json.getPath(obj, entityPath, null);
    if (node == null || node.events == null) return null;
    return node.events[event];
};

// Все события: "#{entity: "form"/путь виджета, event, handler}"
function __jec_collectWidgetEvents(nodeList, basePath) {
    var acc = #[];
    for (var ix = 0; ix < nodeList.size(); ix++) {
        var wItem = nodeList[ix];
        var p = basePath + "[" + str.toString(ix) + "]";
        if (wItem.name != null && wItem.events != null) {
            var namesArr = propertyNames(wItem.events);
            for (var kk = 0; kk < namesArr.size(); kk++) {
                var evKey = namesArr[kk];
                acc.push(#{"entity": wItem.name, "path": p, "event": evKey, "handler": wItem.events[evKey]});
            }
        }
        if (wItem.children != null) {
            var sub = __jec_collectWidgetEvents(wItem.children, p + ".children");
            for (var mm = 0; mm < sub.size(); mm++) acc.push(sub[mm]);
        }
    }
    return acc;
}

function __jec_collectActionEvents(list, basePath, out) {
    if (typeName(list) != "array") return out;
    for (var i = 0; i < list.size(); i++) {
        var action = list[i];
        var p = basePath + "[" + str.toString(i) + "]";
        if (action.events != null && typeName(action.events) == "tuple") {
            var keys = propertyNames(action.events);
            for (var k = 0; k < keys.size(); k++)
                out.push(#{"entity": action.objectName, "path": p, "event": keys[k], "handler": action.events[keys[k]]});
        }
        if (action.children != null) out = __jec_collectActionEvents(action.children, p + ".children", out);
    }
    return out;
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
        out.push(#{"entity": "form", "path": "form.formProperties", "event": ev, "handler": fp.events[ev]});
        }
    }
    if (obj.form.widgets != null) {
        var sub = __jec_collectWidgetEvents(obj.form.widgets, "form.widgets");
        for (var mm = 0; mm < sub.size(); mm++) out.push(sub[mm]);
    }
    var sections = #["menuBar", "toolBar", "statusBar"];
    for (var si = 0; si < sections.size(); si++)
        out = __jec_collectActionEvents(obj.form[sections[si]], "form." + sections[si], out);
    return out;
};

jsonedit.inspect = function(jsonText) {
    var obj = json.parse(jsonText);
    var widgets = #[];
    if (obj.form != null && obj.form.widgets != null && typeName(obj.form.widgets) == "array")
        widgets = __jec_inspectWidgets(obj.form.widgets, "form.widgets", widgets);
    var tables = #[];
    if (obj.rxl != null && typeName(obj.rxl) == "array") for (var i = 0; i < obj.rxl.size(); i++) {
        var t = obj.rxl[i];
        var rows = (t.data != null && t.data.cells != null && typeName(t.data.cells) == "array") ? t.data.cells.size() : 0;
        var cols = 0;
        if (rows > 0) for (var r = 0; r < rows; r++)
            if (typeName(t.data.cells[r]) == "array" && t.data.cells[r].size() > cols) cols = t.data.cells[r].size();
        tables.push(#{"name": t.name, "rows": rows, "cols": cols});
    }
    return #{"objectName": (obj.form != null && obj.form.formProperties != null) ? obj.form.formProperties.objectName : null,
             "widgets": widgets, "tables": tables, "events": jsonedit.collectEvents(jsonText)};
};

function __jec_inspectWidgets(list, base, out) {
    for (var i = 0; i < list.size(); i++) {
        var w = list[i];
        var p = base + "[" + str.toString(i) + "]";
        out.push(#{"name": w.name, "class": w["class"], "path": p});
        if (w.children != null && typeName(w.children) == "array") out = __jec_inspectWidgets(w.children, p + ".children", out);
    }
    return out;
}

jsonedit.setWidgetProperty = function(jsonText, widgetName, property, value) {
    var path = jsonedit.findWidgetPath(jsonText, widgetName);
    if (path == null) throw "jsonedit.setWidgetProperty: виджет не найден: " + widgetName;
    return jsonedit.setText(jsonText, path + ".properties." + property, value);
};

jsonedit.setWidgetPropertyRaw = function(jsonText, widgetName, property, replacementJsonText) {
    var path = jsonedit.findWidgetPath(jsonText, widgetName);
    if (path == null) throw "jsonedit.setWidgetPropertyRaw: виджет не найден: " + widgetName;
    return jsonedit.setTextRaw(jsonText, path + ".properties." + property, replacementJsonText);
};

jsonedit.setWidgetPropertyBool = function(jsonText, widgetName, property, value) {
    var path = jsonedit.findWidgetPath(jsonText, widgetName);
    if (path == null) throw "jsonedit.setWidgetPropertyBool: виджет не найден: " + widgetName;
    return jsonedit.setBool(jsonText, path + ".properties." + property, value);
};

jsonedit.setWidgetEvent = function(jsonText, widgetName, event, handler) {
    var path = jsonedit.findWidgetPath(jsonText, widgetName);
    if (path == null) throw "jsonedit.setWidgetEvent: виджет не найден: " + widgetName;
    return jsonedit.setText(jsonText, path + ".events." + event, handler);
};

jsonedit.renameWidget = function(jsonText, oldName, newName) {
    if (newName == null || newName == "") throw "jsonedit.renameWidget: новое имя не может быть пустым";
    if (jsonedit.findWidgetPath(jsonText, oldName) == null) throw "jsonedit.renameWidget: виджет не найден: " + oldName;
    var existing = jsonedit.findWidgetPath(jsonText, newName);
    if (existing != null && existing != jsonedit.findWidgetPath(jsonText, oldName)) throw "jsonedit.renameWidget: новое имя уже занято: " + newName;
    var path = jsonedit.findWidgetPath(jsonText, oldName);
    return json.replaceText(jsonText, path + ".name", json.stringify(str.toString(newName)), true, 4);
};

jsonedit.renameTable = function(jsonText, oldName, newName) {
    var obj = json.parse(jsonText);
    var index = __jec_findTableIndex(obj, oldName);
    if (index == null) throw "jsonedit.renameTable: таблица не найдена: " + oldName;
    if (__jec_findTableIndex(obj, newName) != null) throw "jsonedit.renameTable: новое имя уже занято: " + newName;
    return json.setField(jsonText, "rxl[" + str.toString(index) + "]", "name", str.toString(newName));
};

jsonedit.setFormProperty = function(jsonText, property, value) {
    return jsonedit.setText(jsonText, "form.formProperties." + property, value);
};

jsonedit.setFormPropertyBool = function(jsonText, property, value) {
    return jsonedit.setBool(jsonText, "form.formProperties." + property, value);
};

function __jec_findTableIndex(obj, name) {
    if (obj.rxl == null || typeName(obj.rxl) != "array") return null;
    var found = null;
    for (var i = 0; i < obj.rxl.size(); i++) if (obj.rxl[i].name == name) {
        if (found != null) throw "jsonedit: неоднозначное имя таблицы: " + name;
        found = i;
    }
    return found;
}

jsonedit.getCell = function(jsonText, tableName, row, col) {
    if (row < 0 || col < 0) return null;
    var obj = json.parse(jsonText);
    var i = __jec_findTableIndex(obj, tableName);
    if (i == null) return null;
    return json.getPath(obj, "rxl[" + str.toString(i) + "].data.cells[" + str.toString(row) + "][" + str.toString(col) + "]", null);
};

jsonedit.setCell = function(jsonText, tableName, row, col, value) {
    if (row < 0 || col < 0) throw "jsonedit.setCell: row/col должны быть >= 0 (0-based)";
    var obj = json.parse(jsonText);
    var i = __jec_findTableIndex(obj, tableName);
    if (i == null) throw "jsonedit.setCell: таблица не найдена: " + tableName;
    var cells = obj.rxl[i].data.cells;
    if (cells == null || typeName(cells) != "array" || row >= cells.size() ||
        typeName(cells[row]) != "array" || col >= cells[row].size())
        throw "jsonedit.setCell: целевая ячейка отсутствует; расширение таблицы требует явной структурной операции";
    var cellPath = "rxl[" + str.toString(i) + "].data.cells[" + str.toString(row) + "][" + str.toString(col) + "]";
    // Меняем только текст: стили, шрифт и маркеры объединения остаются нетронуты.
    var cell = json.getText(jsonText, cellPath);
    if (cell == "{}") cell = "{\"t\":" + json.stringify(str.toString(value)) + "}";
    else cell = json.replaceText(cell, "t", json.stringify(str.toString(value)), false);
    return json.replaceText(jsonText, cellPath, cell, true, 4);
};

jsonedit.resizeTable = function(jsonText, tableName, rows, cols) {
    if (rows < 0 || cols < 0) throw "jsonedit.resizeTable: размеры должны быть >= 0";
    var obj = json.parse(jsonText);
    var i = __jec_findTableIndex(obj, tableName);
    if (i == null) throw "jsonedit.resizeTable: таблица не найдена: " + tableName;
    var cells = obj.rxl[i].data.cells;
    if (cells == null || typeName(cells) != "array") cells = #[];
    while (cells.size() > rows) cells.pop();
    while (cells.size() < rows) cells.push(#[]);
    for (var r = 0; r < cells.size(); r++) {
        while (cells[r].size() > cols) cells[r].pop();
        while (cells[r].size() < cols) cells[r].push(#tuple{});
    }
    var jsonCells = json.stringify(cells);
    var next = json.replaceText(jsonText, "rxl[" + str.toString(i) + "].data.cells", jsonCells, true, 4);
    next = json.replaceText(next, "rxl[" + str.toString(i) + "].info.maxRow", str.toString(rows), true, 4);
    return json.replaceText(next, "rxl[" + str.toString(i) + "].info.maxCol", str.toString(cols), true, 4);
};

jsonedit.validateHandlers = function(jsonText) {
    var obj = json.parse(jsonText);
    var errors = #[];
    var events = jsonedit.collectEvents(jsonText);
    for (var i = 0; i < events.size(); i++) {
        var handler = events[i].handler;
        if (handler == null || handler == "") continue;
        if (funcedit.isUnique(obj.code.text, handler) != 1)
            errors.push(events[i].path + ".events." + events[i].event + ": обработчик '" + handler + "' не найден ровно один раз в code.text");
    }
    var form = obj.form;
    var sections = #["menuBar", "toolBar", "statusBar"];
    for (var si = 0; si < sections.size(); si++) {
        var list = form[sections[si]];
        if (list != null) errors = __jec_validateActionHandlers(list, "form." + sections[si], obj.code.text, errors);
    }
    return #{"ok": (errors.size() == 0), "errors": errors};
};

function __jec_validateActionHandlers(list, base, code, errors) {
    if (typeName(list) != "array") return errors;
    for (var i = 0; i < list.size(); i++) {
        var item = list[i];
        var p = base + "[" + str.toString(i) + "]";
        if (item.events != null && typeName(item.events) == "tuple") {
            var names = propertyNames(item.events);
            for (var k = 0; k < names.size(); k++) {
                var handler = item.events[names[k]];
                if (handler != null && handler != "" && funcedit.isUnique(code, handler) != 1)
                    errors.push(p + ".events." + names[k] + ": обработчик '" + handler + "' не найден ровно один раз в code.text");
            }
        }
        if (item.children != null) errors = __jec_validateActionHandlers(item.children, p + ".children", code, errors);
    }
    return errors;
}

jsonedit.validateCode = function(jsonText) {
    var parsed = json.parseEx(jsonText);
    if (!parsed.ok) return #{"ok": 0, "errors": #["JSON: " + parsed.error.message]};
    if (parsed.value.code == null || typeName(parsed.value.code.text) != "string")
        return #{"ok": 0, "errors": #["code.text: обязательная строка"]};
    if (!json.validateScript(parsed.value.code.text))
        return #{"ok": 0, "errors": #["code.text: ошибка синтаксиса Script"]};
    return #{"ok": 1, "errors": #[]};
};

jsonedit.validateResource = function(jsonText, checkHandlers) {
    var base = jsonedit.validateForm(jsonText);
    var errors = base.errors;
    if (checkHandlers) {
        var code = jsonedit.validateCode(jsonText);
        for (var ci = 0; ci < code.errors.size(); ci++) errors.push(code.errors[ci]);
        var handlers = jsonedit.validateHandlers(jsonText);
        for (var i = 0; i < handlers.errors.size(); i++) errors.push(handlers.errors[i]);
    }
    return #{"ok": (errors.size() == 0), "errors": errors};
};

// Планирование/применение файла. Требует предварительного loadModule(fileedit.prg).
// planFile не пишет файл; applyFile повторно валидирует результат до атомарной записи.
jsonedit.planFile = function(path, transformFn) {
    return fileedit.planEdit(path, function(text) {
        var next = transformFn(text);
        var validation = jsonedit.validateResource(next, 1);
        if (!validation.ok) throw "jsonedit.planFile: результат не прошёл validateForm: " + json.stringify(validation.errors);
        var original = json.parseEx(text);
        var updated = json.parseEx(next);
        if (!original.ok || !updated.ok || original.value.code.text != updated.value.code.text)
            throw "jsonedit.planFile: изменение code.text требует отдельной компиляционной проверки; planFile не применяет кодовые правки";
        return next;
    });
};

jsonedit.applyFile = function(plan, opts) {
    var validation = jsonedit.validateResource(plan.next, 1);
    if (!validation.ok) throw "jsonedit.applyFile: план не прошёл validateForm: " + json.stringify(validation.errors);
    return fileedit.apply(plan, opts);
};
