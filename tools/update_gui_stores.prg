// Дополнительная миграция: правит блок переключения магазинов в GUI.
// - Формирует подписку на currentIndexChanged через events виджета storeCombo
//   (надёжнее, чем программная лямбда).
// - Заменяет старый блок функций переключения содержимым tools/gui_store_block.prg.
// Идемпотентно.
// Запуск: bin\qodeqt.exe tools\update_gui_stores.prg

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

var path = "scanmarket_gui.json";
var raw = file.read(path, file.ENC_UTF8_BOM);
if (raw == null or raw == "")
    throw "Не удалось прочитать scanmarket_gui.json";

var root = json.parse(raw);
if (root == null)
    throw "Не удалось разобрать scanmarket_gui.json";

var code = str.toString(root.code.text);

// Параметризуем ссылку на карточку: открываем любой http(s), не только Ozon.
if (str.pos(code, "str.startswith(link, \"https://www.ozon.ru/product/\")") >= 0)
    code = str.replace(
        code,
        "str.startswith(link, \"https://www.ozon.ru/product/\")",
        "str.startswith(link, \"http\")"
    );

// ---------- 0) Карты магазинов (инициализация, идемпотентно) ----------

// Путь к базе Яндекс Маркета после строки Wildberries.
if (str.pos(code, "var dbYmFile") < 0)
{
    code = str.replace(
        code,
        "var dbWbFile = file.absolute(cfgGet(cfg, \"wildberries.dbPath\", \"private_data/wildberries/wildberries.sqlite\"));",
        "var dbWbFile = file.absolute(cfgGet(cfg, \"wildberries.dbPath\", \"private_data/wildberries/wildberries.sqlite\"));" +
        "\r\nvar dbYmFile = file.absolute(cfgGet(cfg, \"yandexmarket.dbPath\", \"private_data/yandexmarket/yandexmarket.sqlite\"));"
    );
}

if (str.pos(code, "\"yandexmarket\": dbYmFile") < 0)
{
    code = str.replace(
        code,
        "var storeDb = #{\"ozon\": dbOzonFile, \"wildberries\": dbWbFile};",
        "var storeDb = #{\"ozon\": dbOzonFile, \"wildberries\": dbWbFile, \"yandexmarket\": dbYmFile};"
    );
}

// Индексы и списки магазинов для комбо и заголовков.
if (str.pos(code, "var storeSources") < 0)
{
    code = str.replace(
        code,
        "var storeIndex = #{\"ozon\": 0, \"wildberries\": 1};",
        "var storeIndex = #{\"ozon\": 0, \"wildberries\": 1, \"yandexmarket\": 2};" +
        "\r\nvar storeSources = #[\"ozon\", \"wildberries\", \"yandexmarket\"];" +
        "\r\nvar storeLabels = #{\"ozon\": \"Ozon\", \"wildberries\": \"Wildberries\", \"yandexmarket\": \"Яндекс Маркет\"};" +
        "\r\nvar storeTitles = #{\"ozon\": \"OZON\", \"wildberries\": \"WILDBERRIES\", \"yandexmarket\": \"ЯНДЕКС МАРКЕТ\"};"
    );
}

// ---------- 1) Новый блок функций переключения ----------

var blockPath = file.join(projectDir, "tools", "gui_store_block.prg");
var blockRaw = file.read(blockPath, file.ENC_UTF8_BOM);
if (blockRaw != null and str.len(blockRaw) > 0 and str.ord(blockRaw) == 0xFEFF)
    blockRaw = str.sub(blockRaw, 1);
if (blockRaw == null or blockRaw == "")
    throw "Не удалось прочитать блок переключения магазинов";

blockRaw = str.replace(blockRaw, "\r\n", "\n");
blockRaw = str.replace(blockRaw, "\n", "\r\n");

// Удаляем существующий блок: от заголовка "Переключение магазина" до конца файла.
var blockStartMarker = "// ============================================================\r\n// Переключение магазина";
var bs = str.pos(code, blockStartMarker);
if (bs < 0) {
    bs = str.pos(code, "function productRowsSql(source)");
}
if (bs >= 0)
    code = str.rtrim(str.sub(code, 0, bs));

// Добавляем новый блок.
code = str.rtrim(code) + "\r\n" + blockRaw + "\r\n";
root.code.text = code;

// ---------- 2) Подписка events у виджета storeCombo ----------
// Массив/кортежи, полученные из json.parse, модифицировать нельзя —
// собираем массив виджетов заново, заменяя storeCombo копией с событиями.

var widgetsArr = root.form.widgets;
var anyCombo = false;
if (widgetsArr != null)
{
    var newWidgets = #[];
    for (var w : widgetsArr)
    {
        var nm = str.toString(coalesce(w.get("name"), ""));
        if (nm == "storeCombo")
        {
            anyCombo = true;
            var copy = w.clone();
            var ev = copy.get("events");
            if (ev == null)
                copy.set("events", #{"currentIndexChanged": "storeCombo_currentIndexChanged"});
            else
                ev.set("currentIndexChanged", "storeCombo_currentIndexChanged");
            newWidgets.push(copy);
        }
        else
        {
            newWidgets.push(w);
        }
    }
    root.form.widgets = newWidgets;
}

file.write(path, json.stringify(root, true), file.ENC_UTF8_BOM);

var hasFn = str.pos(code, "function storeCombo_currentIndexChanged") >= 0;
print("Готово: блок переключения обновлён; именованная функция=" + str.toString(hasFn)
    + "; events установлены=" + str.toString(anyCombo));
return 0;