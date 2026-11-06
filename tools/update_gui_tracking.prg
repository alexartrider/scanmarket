// Добавляет ручной переключатель отслеживания и отображение состояния избранного.
var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

var path = "scanmarket_gui.json";
var raw = file.read(path, file.ENC_UTF8_BOM);
var source = raw;

if (raw == null or raw == "")
    throw "Не удалось прочитать scanmarket_gui.json";

var root = json.parse(raw);

if (root == null)
    throw "Не удалось разобрать scanmarket_gui.json";

var code = str.toString(root.code.text);

var dynamicButtonStart = str.pos(code, "var trackingButton = qt.create(");

if (dynamicButtonStart >= 0)
{
    var dynamicButtonTail = str.sub(code, dynamicButtonStart);
    var separatorStart = str.pos(dynamicButtonTail, "// ============================================================");

    if (separatorStart < 0)
        throw "Не найден конец ошибочного динамического объявления trackingButton";

    var removeEnd = dynamicButtonStart + separatorStart;
    code = str.sub(code, 0, dynamicButtonStart) + str.sub(code, removeEnd);
}

if (str.pos(code, "var currentProductId = \"\";") < 0)
{
    code = str.replace(
        code,
        "var currentUrl = \"\";",
        "var currentUrl = \"\";\r\n" +
        "var currentProductId = \"\";\r\n" +
        "var currentTrackingEnabled = true;"
    );
}

var migrationAnchor = "// ============================================================\r\n"
    + "// Отображение информации о товаре";

if (str.pos(code, "var trackingSchema = db.query();") < 0)
{
    var migration =
        "var trackingSchema = db.query();\r\n"
        + "trackingSchema.open(\"pragma table_info(products)\");\r\n"
        + "var hasTrackingEnabled = false;\r\n"
        + "var hasFavoriteState = false;\r\n"
        + "while (!trackingSchema.eof())\r\n"
        + "{\r\n"
        + "    var columnName = str.toString(trackingSchema.field(1));\r\n"
        + "    if (columnName == \"tracking_enabled\")\r\n"
        + "        hasTrackingEnabled = true;\r\n"
        + "    if (columnName == \"favorite_state\")\r\n"
        + "        hasFavoriteState = true;\r\n"
        + "    trackingSchema.next();\r\n"
        + "}\r\n"
        + "trackingSchema.close();\r\n"
        + "if (!hasTrackingEnabled)\r\n"
        + "{\r\n"
        + "    var addTrackingColumn = db.query();\r\n"
        + "    addTrackingColumn.execSQL(\r\n"
        + "        \"alter table products add column tracking_enabled integer not null default 1\"\r\n"
        + "    );\r\n"
        + "    addTrackingColumn.close();\r\n"
        + "}\r\n"
        + "if (!hasFavoriteState)\r\n"
        + "{\r\n"
        + "    var addFavoriteStateColumn = db.query();\r\n"
        + "    addFavoriteStateColumn.execSQL(\r\n"
        + "        \"alter table products add column favorite_state text not null default 'unknown'\"\r\n"
        + "    );\r\n"
        + "    addFavoriteStateColumn.close();\r\n"
        + "}\r\n\r\n";

    if (str.pos(code, migrationAnchor) < 0)
        throw "Не найден раздел миграции миниатюры в GUI-коде";

    code = str.replace(code, migrationAnchor, migration + migrationAnchor);
}

var queryAnchor = "coalesce(status, ''), coalesce(best_url, ''), thumbnail ";
var queryReplacement = "coalesce(status, ''), coalesce(best_url, ''), thumbnail, "
    + "coalesce(tracking_enabled, 1), coalesce(favorite_state, 'unknown') ";

var queryColumnStart = str.pos(code, queryAnchor);
if (queryColumnStart < 0)
    queryColumnStart = str.pos(code, "coalesce(status, ''), coalesce(best_url, ''), thumbnail,");

if (queryColumnStart >= 0 and str.pos(code, queryReplacement) < 0)
{
    var foundQueryAnchor = str.sub(code, queryColumnStart, str.len(queryAnchor));
    if (foundQueryAnchor == queryAnchor)
        code = str.sub(code, 0, queryColumnStart)
            + queryReplacement
            + str.sub(code, queryColumnStart + str.len(queryAnchor));
}

var stateReadAnchor = "var thumbBytes = q.field(5);";
var stateStart = str.pos(code, stateReadAnchor);

if (stateStart < 0)
    throw "Не найдено чтение BLOB миниатюры в showProduct";

var stateTail = str.sub(code, stateStart);
var queryCloseOffset = str.pos(stateTail, "    q.close();");

if (queryCloseOffset < 0)
    throw "Не найден конец SELECT при добавлении кнопки отслеживания";

var queryCloseEnd = stateStart + queryCloseOffset + str.len("    q.close();");
var afterQuery = str.sub(code, queryCloseEnd);
var thumbBlockMarker = str.pos(afterQuery, "form.thumbLabel.clear();");

if (thumbBlockMarker < 0)
    throw "Не найден блок миниатюры в showProduct";

var buttonUpdate =
    "    form.trackingButton.enabled = true;\r\n"
    + "    form.trackingButton.text = currentTrackingEnabled\r\n"
    + "        ? \"Не отслеживать\"\r\n"
    + "        : \"Возобновить\";\r\n\r\n";

var beforeQueryClose = str.sub(code, 0, stateStart);
var queryReadBlock =
    "    var thumbBytes = q.field(5);\r\n"
    + "    currentProductId = id;\r\n"
    + "    currentTrackingEnabled = (q.field(6) != 0);\r\n"
    + "    var favoriteState = str.toString(q.field(7));\r\n\r\n"
    + "    q.close();\r\n\r\n"
    + buttonUpdate;
var afterThumbMarker = str.sub(afterQuery, thumbBlockMarker);

code = beforeQueryClose + queryReadBlock + afterThumbMarker;

var gridHandlerAnchor = "function productsGrid_currentRowChanged(Sender, rowIndex)";

var buttonHandlerStart = str.pos(code, "function trackingButton_clicked(Sender, checked)");
var gridHandlerPosition = str.pos(code, gridHandlerAnchor);

if (buttonHandlerStart < 0 or
    (gridHandlerPosition >= 0 and gridHandlerPosition < buttonHandlerStart))
{
    var buttonHandler =
        "function trackingButton_clicked(Sender, checked)\r\n"
        + "{\r\n"
        + "    if (currentProductId == \"\")\r\n"
        + "        return;\r\n"
        + "\r\n"
        + "    currentTrackingEnabled = !currentTrackingEnabled;\r\n"
        + "    var trackingValue = currentTrackingEnabled ? 1 : 0;\r\n"
        + "    var updateTracking = db.query();\r\n"
        + "    updateTracking.execSQL(\r\n"
        + "        \"update products set tracking_enabled = ? where source = 'ozon' and product_id = ?\",\r\n"
        + "        #[trackingValue, currentProductId]\r\n"
        + "    );\r\n"
        + "    updateTracking.close();\r\n"
        + "\r\n"
        + "    form.trackingButton.text = currentTrackingEnabled\r\n"
        + "        ? \"Не отслеживать\"\r\n"
        + "        : \"Возобновить\";\r\n"
        + "    form.productsGrid.refresh();\r\n"
        + "    form.statusLabel.text = currentTrackingEnabled\r\n"
        + "        ? \"Отслеживание товара возобновлено\"\r\n"
        + "        : \"Товар исключён из отслеживания; история сохранена\";\r\n"
        + "}\r\n\r\n";

    var stateHandlerAnchor = "function thumbLabel_linkActivated(Sender, href)";
    var showHandlerAnchor = "function showProduct(rowIndex)";

    if (str.pos(code, showHandlerAnchor) >= 0)
        code = str.replace(code, showHandlerAnchor, buttonHandler + showHandlerAnchor);
    else if (str.pos(code, stateHandlerAnchor) >= 0)
        code = str.replace(code, stateHandlerAnchor, buttonHandler + stateHandlerAnchor);
    else if (str.pos(code, gridHandlerAnchor) >= 0)
        code = str.replace(code, gridHandlerAnchor, buttonHandler + gridHandlerAnchor);
    else
        throw "Не найден обработчик формы для объявления кнопки отслеживания";
}

var newStatusSql = "case when p.status='out_of_stock' then 'Нет в наличии' " +
    "when p.favorite_state='not_in_favorites' then 'Убрано из избранного' " +
    "when coalesce(p.tracking_enabled,1)=0 then 'Не отслеживается' " +
    "else coalesce(p.status,'') end as status";

function findWidget(items, targetName)
{
    if (items == null)
        return null;

    for (var widget : items)
    {
        if (str.toString(coalesce(widget.get("name"), "")) == targetName)
            return widget;

        var found = findWidget(widget.get("children"), targetName);
        if (found != null)
            return found;
    }

    return null;
}

var productsGrid = findWidget(root.form.widgets, "productsGrid");
var cardFrame = findWidget(root.form.widgets, "qFrameCardInfo");
var dynamicFrame = findWidget(root.form.widgets, "qFrameDynamic");

if (productsGrid == null or cardFrame == null or dynamicFrame == null)
    throw "В форме не найдены сетка или панели карточки товара";

var gridSql = str.toString(productsGrid.properties.sql);
var oldStatusStart = str.pos(gridSql, "case when p.status=");
var newStatusSql = "case when p.status='out_of_stock' then 'Нет в наличии' " +
    "when p.favorite_state='not_in_favorites' then 'Убрано из избранного' " +
    "when coalesce(p.tracking_enabled,1)=0 then 'Не отслеживается' " +
    "else coalesce(p.status,'') end as status";

if (oldStatusStart >= 0)
{
    var caseTail = str.sub(gridSql, oldStatusStart);
    var caseEndRelative = str.pos(caseTail, "end as status");

    if (caseEndRelative >= 0)
    {
        var caseEnd = oldStatusStart + caseEndRelative + str.len("end as status");
        gridSql = str.sub(gridSql, 0, oldStatusStart)
            + newStatusSql
            + str.sub(gridSql, caseEnd);
        productsGrid.set("sql", gridSql);
    }
}

var cardFrameObject = findWidget(root.form.widgets, "qFrameCardInfo");
var rightFrame = findWidget(root.form.widgets, "qFrameRight");

if (cardFrameObject == null or rightFrame == null)
    throw "Не найден контейнер карточки товара для новой кнопки";

var newButton = #{
    "align": 0,
    "alignMargins": #{"b": 0, "l": 0, "r": 0, "t": 0},
    "anchorMargins": #{"b": 4, "l": 553, "r": 28, "t": 132},
    "anchors": 3,
    "class": "QPushButton",
    "events": #{"clicked": "trackingButton_clicked"},
    "geometry": #{"h": 28, "w": 180, "x": 553, "y": 132},
    "name": "trackingButton",
    "properties": #{
        "enabled": 0,
        "font": "Segoe UI,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0",
        "text": "Не отслеживать",
        "toolTip": "Отключить обновление цены, не удаляя историю",
        "visible": 1
    }
};

function updateWidgetTree(widget)
{
    var widgetName = str.toString(coalesce(widget.get("name"), ""));
    var children = widget.get("children");
    var updatedChildren = #[];

    if (widgetName == "qFrameRight")
    {
        var cardFrame = null;
        var dynamicFrame = null;
        var otherChildren = #[];

        for (var child : children)
        {
            var childName = str.toString(coalesce(child.get("name"), ""));

            if (childName == "qFrameCardInfo")
                cardFrame = child;
            else if (childName == "qFrameDynamic")
                dynamicFrame = child;
            else
                otherChildren.push(updateWidgetTree(child));
        }

        if (cardFrame != null)
            updatedChildren.push(updateWidgetTree(cardFrame));

        if (dynamicFrame != null)
            updatedChildren.push(updateWidgetTree(dynamicFrame));

        for (var otherChild : otherChildren)
            updatedChildren.push(otherChild);
    }
    else if (widgetName == "qFrameCardInfo")
    {
        var thumbnail = null;

        for (var child : children)
        {
            var childName = str.toString(coalesce(child.get("name"), ""));

            if (childName == "trackingButton")
                continue;

            if (childName == "thumbLabel")
                thumbnail = child;

            updatedChildren.push(updateWidgetTree(child));
        }

        if (thumbnail != null)
        {
            thumbnail.set("geometry", #{"h": 129, "w": 129, "x": 0, "y": 0});
            thumbnail.set("anchorMargins", #{"b": 35, "l": 0, "r": 632, "t": 0});
            thumbnail.set("align", 0);

            for (var i = 0; i < updatedChildren.size(); i++)
            {
                if (str.toString(coalesce(updatedChildren[i].get("name"), "")) == "thumbLabel")
                {
                    updatedChildren[i] = thumbnail;
                    break;
                }
            }
        }

        updatedChildren.push(newButton);
        widget.set("geometry", #{"h": 164, "w": 761, "x": 0, "y": 0});
        widget.set("anchorMargins", #{"b": 549, "l": 0, "r": 0, "t": 0});
        widget.set("align", 0);
    }
    else if (widgetName == "qFrameDynamic")
    {
        if (children != null)
        {
            for (var child : children)
                updatedChildren.push(updateWidgetTree(child));
        }

        widget.set("geometry", #{"h": 575, "w": 761, "x": 0, "y": 164});
        widget.set("anchorMargins", #{"b": 0, "l": 0, "r": 0, "t": 164});
        widget.set("align", 0);
    }
    else if (children != null)
    {
        for (var child : children)
        {
            if (str.toString(coalesce(child.get("name"), "")) == "trackingButton")
                continue;

            updatedChildren.push(updateWidgetTree(child));
        }
    }

    widget.set("children", updatedChildren);

    return widget;
}

var updatedWidgets = #[];

for (var widget : root.form.widgets)
{
    if (str.toString(coalesce(widget.get("name"), "")) == "trackingButton")
        continue;

    updatedWidgets.push(updateWidgetTree(widget));
}

root.form.set("widgets", updatedWidgets);

var thumbHandlerLine = "function thumbLabel_linkActivated(Sender, href)";

if (str.pos(code, thumbHandlerLine) < 0)
{
    var thumbHandlerCode =
        "function thumbLabel_linkActivated(Sender, href)\r\n"
        + "{\r\n"
        + "    var link = str.toString(coalesce(href, \"\"));\r\n"
        + "    if (str.startswith(link, \"https://www.ozon.ru/product/\"))\r\n"
        + "        qt.openUrl(link);\r\n"
        + "}\r\n\r\n";

    var showHandlerPosition = str.pos(code, "function showProduct(rowIndex)");
    var thumbHandlerInsert = showHandlerPosition;

    if (showHandlerPosition >= 0)
    {
        var codeBeforeShowHandler = str.sub(code, 0, showHandlerPosition);
        var buttonHandlerPosition = str.pos(codeBeforeShowHandler,
            "function trackingButton_clicked(Sender, checked)");

        if (buttonHandlerPosition >= 0)
            thumbHandlerInsert = buttonHandlerPosition;
    }

    if (thumbHandlerInsert < 0)
        throw "Не найдено место для обработчика ссылки миниатюры";

    code = str.sub(code, 0, thumbHandlerInsert)
        + thumbHandlerCode
        + str.sub(code, thumbHandlerInsert);
}

var trackingHandlerStart = str.pos(code,
    "function trackingButton_clicked(Sender, checked)");
var showProductStart = str.pos(code, "function showProduct(rowIndex)");

var oldRowHandler = str.pos(code,
    "function productsGrid_currentRowChanged(Sender, rowIndex)");

if (oldRowHandler >= 0)
{
    var eventTail = str.sub(code, oldRowHandler);
    var eventEnd = str.pos(eventTail, "}\r\n");

    if (eventEnd >= 0)
        code = str.sub(code, 0, oldRowHandler)
            + str.sub(eventTail, eventEnd + 3);
}

if (trackingHandlerStart >= 0 and showProductStart >= 0 and
    trackingHandlerStart < showProductStart)
{
    var trackingHandlerTail = str.sub(code, trackingHandlerStart);
    var trackingHandlerEnd = str.pos(trackingHandlerTail,
        "function showProduct(rowIndex)");
    code = str.sub(code, 0, trackingHandlerStart)
        + str.sub(trackingHandlerTail, trackingHandlerEnd);
}

var widgetRowHandlerStart = str.pos(code,
    "function productsGrid_currentRowChanged(Sender, rowIndex)");

if (widgetRowHandlerStart >= 0)
{
    var widgetRowTail = str.sub(code, widgetRowHandlerStart);
    var widgetRowEnd = str.pos(widgetRowTail, "}\r\n");

    if (widgetRowEnd >= 0)
        code = str.sub(code, 0, widgetRowHandlerStart)
            + str.sub(widgetRowTail, widgetRowEnd + 3);
}

trackingHandlerStart = str.pos(code,
    "function trackingButton_clicked(Sender, checked)");
showProductStart = str.pos(code, "function showProduct(rowIndex)");

if (trackingHandlerStart >= 0 and showProductStart >= 0 and
    trackingHandlerStart > showProductStart)
{
    var handlerTail = str.sub(code, trackingHandlerStart);
    var handlerEnd = str.pos(handlerTail, "}\r\n");
    var handlerText = str.sub(handlerTail, 0, handlerEnd + 3);
    code = str.sub(code, 0, trackingHandlerStart)
        + str.sub(handlerTail, handlerEnd + 3);

    showProductStart = str.pos(code, "function showProduct(rowIndex)");
    code = str.sub(code, 0, showProductStart)
        + handlerText
        + str.sub(code, showProductStart);
}

var oldThumbHandler = str.pos(code,
    "function thumbLabel_linkActivated(Sender, href)");
var trackingFunctionPosition = str.pos(code,
    "function trackingButton_clicked(Sender, checked)");
showProductStart = str.pos(code, "function showProduct(rowIndex)");

if (oldThumbHandler >= 0 and trackingFunctionPosition >= 0 and
    oldThumbHandler > trackingFunctionPosition)
{
    var oldThumbTail = str.sub(code, oldThumbHandler);
    var oldThumbEnd = str.pos(oldThumbTail, "}\r\n");

    if (oldThumbEnd >= 0)
    {
        var oldThumbText = str.sub(oldThumbTail, 0, oldThumbEnd + 3);
        code = str.sub(code, 0, oldThumbHandler)
            + str.sub(oldThumbTail, oldThumbEnd + 3);

        trackingFunctionPosition = str.pos(code,
            "function trackingButton_clicked(Sender, checked)");
        code = str.sub(code, 0, trackingFunctionPosition)
            + oldThumbText
            + str.sub(code, trackingFunctionPosition);
    }
}

if (str.pos(code, thumbHandlerLine) < 0)
{
    trackingHandlerStart = str.pos(code,
        "function trackingButton_clicked(Sender, checked)");
    showProductStart = str.pos(code, "function showProduct(rowIndex)");

    if (trackingHandlerStart < 0 or showProductStart < 0 or
        trackingHandlerStart > showProductStart)
        throw "Не удалось определить место функции ссылки миниатюры";

    var linkHandler =
        "function thumbLabel_linkActivated(Sender, href)\r\n"
        + "{\r\n"
        + "    var link = str.toString(coalesce(href, \"\"));\r\n"
        + "    if (str.startswith(link, \"https://www.ozon.ru/product/\"))\r\n"
        + "        qt.openUrl(link);\r\n"
        + "}\r\n\r\n";

    code = str.sub(code, 0, trackingHandlerStart)
        + linkHandler
        + str.sub(code, trackingHandlerStart);
}

var thumbSignalLine = "form.thumbLabel.linkActivated = thumbLabel_linkActivated;";

if (str.pos(code, thumbSignalLine) < 0)
{
    var thumbSignalInsert = str.pos(code, "function showProduct(rowIndex)");

    if (thumbSignalInsert >= 0)
    {
        var codeBeforeShowForSignal = str.sub(code, 0, thumbSignalInsert);
        var thumbHandlerPosition = str.pos(codeBeforeShowForSignal,
            "function thumbLabel_linkActivated(Sender, href)");

        if (thumbHandlerPosition >= 0)
            thumbSignalInsert = thumbHandlerPosition;
    }

    if (thumbSignalInsert < 0)
        throw "Не найдено место для подключения ссылки миниатюры";

    code = str.sub(code, 0, thumbSignalInsert)
        + thumbSignalLine + "\r\n\r\n"
        + str.sub(code, thumbSignalInsert);
}

var buttonSignalLine = "form.trackingButton.clicked = trackingButton_clicked;";
var thumbSignalLine = "form.thumbLabel.linkActivated = thumbLabel_linkActivated;";

code = str.replace(code, buttonSignalLine, "");
code = str.replace(code, thumbSignalLine, "");

var rowHandlerAnchor = "function productsGrid_currentRowChanged(Sender, rowIndex)";
var rowHandlerPosition = str.pos(code, rowHandlerAnchor);

if (rowHandlerPosition < 0)
    throw "Не найден обработчик выбора товара";

var moduleCode = str.sub(code, 0, rowHandlerPosition);
var eventCode = str.sub(code, rowHandlerPosition);

var trackingHandlerStart = str.pos(moduleCode,
    "function trackingButton_clicked(Sender, checked)");
var showProductStart = str.pos(moduleCode, "function showProduct(rowIndex)");

if (trackingHandlerStart < 0 or showProductStart < 0)
    throw "Не найдены обработчики ручного отслеживания и карточки";

var trackingHandlerCode = str.sub(moduleCode, trackingHandlerStart,
    showProductStart - trackingHandlerStart);
var moduleBeforeTracking = str.sub(moduleCode, 0, trackingHandlerStart);
var moduleAfterShow = str.sub(moduleCode, showProductStart);

if (str.pos(trackingHandlerCode, "function thumbLabel_linkActivated(Sender, href)") < 0)
{
    var linkHandler =
        "function thumbLabel_linkActivated(Sender, href)\r\n"
        + "{\r\n"
        + "    var link = str.toString(coalesce(href, \"\"));\r\n"
        + "    if (str.startswith(link, \"https://www.ozon.ru/product/\"))\r\n"
        + "        qt.openUrl(link);\r\n"
        + "}\r\n\r\n";

    trackingHandlerCode = linkHandler + trackingHandlerCode;
}

code = moduleBeforeTracking
    + thumbSignalLine + "\r\n"
    + buttonSignalLine + "\r\n\r\n"
    + trackingHandlerCode
    + moduleAfterShow
    + "function productsGrid_currentRowChanged(Sender, rowIndex)\r\n"
    + "{\r\n"
    + "    showProduct(rowIndex);\r\n"
    + "}\r\n";

root.code.text = code;

file.write(path, json.stringify(root, true), file.ENC_UTF8_BOM);
print("Добавлена миграция состояния избранного и ручной кнопки отслеживания");
return 0;
