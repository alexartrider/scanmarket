// Миграция GUI: добавляет кнопки запуска сканирования в scanmarket_gui.json.
// - scanButton  — «Сканировать» (выбранный магазин)
// - scanAllButton — «Сканировать все» (последовательно через scan_all.prg)
// - сужает storeCombo, чтобы кнопки поместились в верхней строке
// - вставляет блок функций запуска (tools/gui_scan_block.prg) в code.text
// Идемпотентно: при повторном запуске ничего не меняет.
// Запуск: bin\qodeqt.exe tools\add_gui_scan_buttons.prg

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule(file.join(projectDir, "scriptlib", "jsonedit.prg"));
loadModule(file.join(projectDir, "scriptlib", "funcedit.prg"));
loadModule(file.join(projectDir, "scriptlib", "fileedit.prg"));

var guiFile = file.join(projectDir, "scanmarket_gui.json");

// ---------- 1) Проверка исходного ресурса ----------

var meta = file.readmeta(guiFile);
var text = meta.text;

var baseCheck = jsonedit.validateResource(text, 1);
if (!baseCheck.ok)
    throw "Исходный GUI невалиден: " + json.stringify(baseCheck.errors);

var blockPath = file.join(projectDir, "tools", "gui_scan_block.prg");
var blockRaw = file.read(blockPath, file.ENC_UTF8_BOM);
if (blockRaw != null and str.len(blockRaw) > 0 and str.ord(blockRaw) == 0xFEFF)
    blockRaw = str.sub(blockRaw, 1);
if (blockRaw == null or blockRaw == "")
    throw "Не удалось прочитать блок кода кнопок";

blockRaw = str.replace(blockRaw, "\r\n", "\n");
blockRaw = str.replace(blockRaw, "\n", "\r\n");

// ---------- 2) Идемпотентность ----------

if (jsonedit.findWidgetPath(text, "scanButton") != null)
{
    var existingRoot = json.parse(text);
    var existingCode = str.toString(existingRoot.code.text);
    var blockMarker = "// ============================================================\r\n" +
        "// Запуск сканирования магазинов";
    var existingBlockStart = str.pos(existingCode, blockMarker);

    if (existingBlockStart < 0)
        throw "Кнопки найдены, но блок их обработчиков не найден в code.text";

    var updatedCode = str.rtrim(str.sub(existingCode, 0, existingBlockStart)) +
        "\r\n" + blockRaw + "\r\n";

    var updatePlan = fileedit.planEdit(guiFile, function(current) {
        return jsonedit.setText(current, "code.text", updatedCode);
    });

    var updateCheck = jsonedit.validateResource(updatePlan.next, 1);
    if (!updateCheck.ok)
        throw "Обновлённый GUI невалиден: " + json.stringify(updateCheck.errors);

    var updateResult = fileedit.apply(updatePlan);
    print(updateResult == 1
        ? "Кнопки уже есть; обработчики сканирования обновлены"
        : "Кнопки и обработчики сканирования уже актуальны");
    return 0;
}

// ---------- 3) Подготовка данных ----------

var trackPath = jsonedit.findWidgetPath(text, "trackingButton");
if (trackPath == null)
    throw "Не найден виджет trackingButton (образец кнопки)";

var tmpl = jsonedit.getText(text, trackPath);

var rootOld = json.parse(text);
var widgetsOld = rootOld.form.widgets;
var codeOld = str.toString(rootOld.code.text);

// ---------- 4) Сборка нового массива виджетов ----------

var newWidgets = #[];

for (var i = 0; i < widgetsOld.size(); i++)
{
    var w = widgetsOld[i];

    // Сужаем комбо выбора магазина, чтобы кнопки поместились справа.
    if (w.name == "storeCombo")
    {
        var cmb = w.clone();
        var cg = cmb.get("geometry").clone();
        cg.set("w", 906);
        cmb.set("geometry", cg);
        newWidgets.push(cmb);
    }
    else
    {
        newWidgets.push(w);
    }
}

// Кнопка «Сканировать» (выбранный магазин).
var b1 = tmpl.clone();
b1.set("name", "scanButton");
b1.set("events", #{"clicked": "scanButton_clicked"});
b1.set("geometry", #{"h": 28, "w": 140, "x": 914, "y": 60});
b1.set("anchors", 3);
b1.set("align", 0);
b1.set("alignMargins", #{"b": 0, "l": 0, "r": 0, "t": 0});
b1.set("anchorMargins", #{"b": 0, "l": 0, "r": 0, "t": 0});
var p1 = tmpl.get("properties").clone();
p1.set("text", "Сканировать");
p1.set("enabled", 1);
p1.set("toolTip", "Запустить сканирование выбранного магазина");
b1.set("properties", p1);
newWidgets.push(b1);

// Кнопка «Сканировать все» (все магазины по очереди).
var b2 = tmpl.clone();
b2.set("name", "scanAllButton");
b2.set("events", #{"clicked": "scanAllButton_clicked"});
b2.set("geometry", #{"h": 28, "w": 244, "x": 1062, "y": 60});
b2.set("anchors", 3);
b2.set("align", 0);
b2.set("alignMargins", #{"b": 0, "l": 0, "r": 0, "t": 0});
b2.set("anchorMargins", #{"b": 0, "l": 0, "r": 0, "t": 0});
var p2 = tmpl.get("properties").clone();
p2.set("text", "Сканировать все");
p2.set("enabled", 1);
p2.set("toolTip", "Последовательно отсканировать все магазины");
b2.set("properties", p2);
newWidgets.push(b2);

// ---------- 5) Вставка блока кода ----------

var newCode = codeOld + "\r\n" + blockRaw + "\r\n";

// ---------- 6) Применение через fileedit (сохраняет кодировку) ----------

var plan = fileedit.planEdit(guiFile, function(current) {
    var next = jsonedit.setText(current, "form.widgets", newWidgets);
    next = jsonedit.setText(next, "code.text", newCode);

    var check = jsonedit.validateResource(next, 1);
    if (!check.ok)
        throw "Результат невалиден: " + json.stringify(check.errors);

    return next;
});

var applied = fileedit.apply(plan);
if (applied != 1)
    throw "Файл не изменился: " + guiFile;

// ---------- 7) Финальная проверка ----------

var finalCheck = jsonedit.validateResource(file.readmeta(guiFile).text, 1);
if (!finalCheck.ok)
    throw "После записи GUI невалиден: " + json.stringify(finalCheck.errors);

print("Готово: кнопки сканирования добавлены в scanmarket_gui.json");
print("События: scanButton -> scanButton_clicked; scanAllButton -> scanAllButton_clicked");
return 0;
