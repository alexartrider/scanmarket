// Миграция GUI: добавляет кнопку «Проверить обновления».
// Проверяются только PRG/JSON-ресурсы; config.json и служебные каталоги исключены.
// JSON меняется точечно, без повторной сериализации существующих Qt-полей.

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule(file.join(projectDir, "scriptlib", "jsonedit.prg"));
loadModule(file.join(projectDir, "scriptlib", "funcedit.prg"));
loadModule(file.join(projectDir, "scriptlib", "fileedit.prg"));

var guiFile = file.join(projectDir, "scanmarket_gui.json");
var blockPath = file.join(projectDir, "tools", "gui_update_check_block.prg");

function replaceJsonValue(jsonText, path, value)
{
    return json.replaceText(jsonText, path, json.stringify(value), true, 4);
}

function buildUpdatedResource(current)
{
    var root = json.parse(current);
    if (root == null or root.form == null or root.form.widgets == null)
        throw "Некорректная структура scanmarket_gui.json";

    var blockRaw = file.read(blockPath, file.ENC_UTF8_BOM);
    if (blockRaw != null and str.len(blockRaw) > 0 and str.ord(blockRaw) == 0xFEFF)
        blockRaw = str.sub(blockRaw, 1);
    if (blockRaw == null or blockRaw == "")
        throw "Не удалось прочитать блок проверки обновлений";

    blockRaw = str.replace(blockRaw, "\r\n", "\n");
    blockRaw = str.replace(blockRaw, "\n", "\r\n");

    var widgetsJson = json.getText(current, "form.widgets");
    var checkButtonPath = jsonedit.findWidgetPath(current, "checkUpdatesButton");
    var foundCheckButton = (checkButtonPath != null);

    if (!foundCheckButton)
    {
        var scanButtonPath = jsonedit.findWidgetPath(current, "scanButton");
        if (scanButtonPath == null)
            throw "Не найден виджет scanButton (образец кнопки)";

        var checkButtonJson = json.getText(current, scanButtonPath);
        checkButtonJson = replaceJsonValue(checkButtonJson, "name", "checkUpdatesButton");
        checkButtonJson = replaceJsonValue(
            checkButtonJson,
            "events",
            #{"clicked": "checkUpdatesButton_clicked"}
        );
        checkButtonJson = replaceJsonValue(
            checkButtonJson,
            "properties.text",
            "Проверить обновления"
        );
        checkButtonJson = replaceJsonValue(
            checkButtonJson,
            "properties.toolTip",
            "Проверить новые версии PRG/JSON-файлов на GitHub"
        );

        var buttonPosition = widgetsJson.rfind("]");
        if (buttonPosition < 0)
            throw "Не удалось найти конец списка виджетов";

        var beforeEnd = str.rtrim(str.sub(widgetsJson, 0, buttonPosition));
        var separator = (root.form.widgets.size() > 0) ? ",\n" : "\n";
        widgetsJson = beforeEnd + separator + checkButtonJson + "\n]";
    }

    var next = json.replaceText(current, "form.widgets", widgetsJson, true, 4);
    var storeComboPath = jsonedit.findWidgetPath(next, "storeCombo");
    var scanButtonPath = jsonedit.findWidgetPath(next, "scanButton");
    var scanAllButtonPath = jsonedit.findWidgetPath(next, "scanAllButton");
    checkButtonPath = jsonedit.findWidgetPath(next, "checkUpdatesButton");

    if (storeComboPath == null or scanButtonPath == null
        or scanAllButtonPath == null or checkButtonPath == null)
        throw "Не найдены виджеты верхней панели";

    next = replaceJsonValue(next, storeComboPath + ".geometry.w", 675);
    next = replaceJsonValue(next, scanButtonPath + ".geometry.x", 683);
    next = replaceJsonValue(next, scanButtonPath + ".anchorMargins.l", 683);
    next = replaceJsonValue(next, scanButtonPath + ".anchorMargins.r", 492);
    next = replaceJsonValue(next, scanAllButtonPath + ".geometry.x", 831);
    next = replaceJsonValue(next, scanAllButtonPath + ".anchorMargins.l", 831);
    next = replaceJsonValue(next, scanAllButtonPath + ".anchorMargins.r", 240);
    next = replaceJsonValue(next, checkButtonPath + ".geometry.x", 1083);
    next = replaceJsonValue(next, checkButtonPath + ".geometry.w", 220);
    next = replaceJsonValue(next, checkButtonPath + ".anchorMargins.l", 1083);
    next = replaceJsonValue(next, checkButtonPath + ".anchorMargins.r", 12);
    next = replaceJsonValue(
        next,
        checkButtonPath + ".events",
        #{"clicked": "checkUpdatesButton_clicked"}
    );
    next = replaceJsonValue(
        next,
        checkButtonPath + ".properties.text",
        "Проверить обновления"
    );
    next = replaceJsonValue(
        next,
        checkButtonPath + ".properties.toolTip",
        "Проверить новые версии PRG/JSON-файлов на GitHub"
    );

    var code = str.toString(root.code.text);
    var marker = "// ============================================================\r\n"
        + "// Проверка обновлений ресурсов ScanMarket из GitHub";
    var markerPosition = str.pos(code, marker);
    if (markerPosition >= 0)
        code = str.rtrim(str.sub(code, 0, markerPosition));

    var updatedCode = str.rtrim(code) + "\r\n" + blockRaw + "\r\n";
    next = replaceJsonValue(next, "code.text", updatedCode);

    return next;
}

var raw = file.read(guiFile, file.ENC_UTF8_BOM);
if (raw == null or raw == "")
    throw "Не удалось прочитать scanmarket_gui.json";

var plan = fileedit.planEdit(guiFile, function(current)
{
    return buildUpdatedResource(current);
});

var planCheck = jsonedit.validateResource(plan.next, 1);
if (!planCheck.ok)
    throw "Результат миграции GUI невалиден: " + json.stringify(planCheck.errors);

var applied = fileedit.apply(plan);
if (applied != 0 and applied != 1)
    throw "GUI не изменён: " + guiFile;

var finalCheck = jsonedit.validateResource(file.read(guiFile, file.ENC_UTF8_BOM), 1);
if (!finalCheck.ok)
    throw "После записи GUI невалиден: " + json.stringify(finalCheck.errors);

if (applied == 0)
    print("GUI уже актуален: повторный запуск ничего не менял");
else
    print("Готово: кнопка проверки обновлений добавлена или обновлена");

return 0;
