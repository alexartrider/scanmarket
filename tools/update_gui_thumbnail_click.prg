// Ссылка на карточку остаётся доступной, даже если BLOB миниатюры отсутствует.
var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

var path = "scanmarket_gui.json";
var source = file.read(path, file.ENC_UTF8_BOM);

if (source == null or source == "")
    throw "Не удалось прочитать scanmarket_gui.json в UTF-8";

var root = json.parse(source);

if (root == null)
    throw "Не удалось разобрать scanmarket_gui.json";

var code = str.toString(root.get("code").get("text"));
var blockStart = str.pos(code, "    form.thumbLabel.clear();");
var blockEnd = str.pos(code, "    var idQ = str.quoted(id);");

if (blockStart < 0 or blockEnd <= blockStart)
    throw "Не найден блок отображения выбранного товара";

var thumbBlock = "    // Ссылка на карточку доступна и при отсутствии миниатюры.\r\n"
    + "    form.thumbLabel.clear();\r\n"
    + "    form.thumbLabel.textFormat = 2;\r\n"
    + "    form.thumbLabel.textInteractionFlags = 4;\r\n"
    + "    form.thumbLabel.openExternalLinks = false;\r\n"
    + "\r\n"
    + "    if (currentUrl != \"\")\r\n"
    + "    {\r\n"
    + "        var imageHtml = \"<a href=\\\"\" + currentUrl + \"\\\">\";\r\n"
    + "\r\n"
    + "        if (thumbBytes != null)\r\n"
    + "        {\r\n"
    + "            imageHtml = imageHtml + \"<img width=\\\"96\\\" height=\\\"96\\\" alt=\\\"Нет фото\\\" src=\\\"data:image/png;base64,\"\r\n"
    + "                + thumbBytes.base64() + \"\\\">\";\r\n"
    + "        }\r\n"
    + "        else\r\n"
    + "        {\r\n"
    + "            imageHtml = imageHtml + \"Нет фото\";\r\n"
    + "        }\r\n"
    + "\r\n"
    + "        imageHtml = imageHtml + \"</a>\";\r\n"
    + "        form.thumbLabel.text = imageHtml;\r\n"
    + "    }\r\n"
    + "    else\r\n"
    + "    {\r\n"
    + "        form.thumbLabel.text = \"Нет фото\";\r\n"
    + "    }\r\n"
    + "\r\n\r\n";

code = str.sub(code, 0, blockStart) + thumbBlock + str.sub(code, blockEnd);

var handlerName = "function thumbLabel_linkActivated(Sender, href)";
var handlerAnchor = "function showProduct(rowIndex)";
var rowHandlerAnchor = "function productsGrid_currentRowChanged(Sender, rowIndex)";

if (str.pos(code, handlerAnchor) < 0 or str.pos(code, rowHandlerAnchor) < 0)
    throw "Не найдены функции карточки и обработчика выбора товара";

if (str.pos(code, handlerName) < 0)
{
    var handler = "function thumbLabel_linkActivated(Sender, href)\r\n"
        + "{\r\n"
        + "    var link = str.toString(coalesce(href, \"\"));\r\n"
        + "    if (str.startswith(link, \"https://www.ozon.ru/product/\"))\r\n"
        + "        qt.openUrl(link);\r\n"
        + "}\r\n\r\n";

    var buttonHandlerPosition = str.pos(code,
        "function trackingButton_clicked(Sender, checked)");
    var insertPosition = str.pos(code, handlerAnchor);

    if (buttonHandlerPosition >= 0 and buttonHandlerPosition < insertPosition)
        insertPosition = buttonHandlerPosition;

    code = str.sub(code, 0, insertPosition)
        + handler
        + str.sub(code, insertPosition);
}

var connectLine = "form.thumbLabel.linkActivated = thumbLabel_linkActivated;";

if (str.pos(code, connectLine) < 0)
{
    var signalPosition = str.pos(code, handlerAnchor);
    var buttonHandlerPosition = str.pos(code,
        "function trackingButton_clicked(Sender, checked)");

    if (buttonHandlerPosition >= 0 and buttonHandlerPosition < signalPosition)
        signalPosition = buttonHandlerPosition;

    code = str.sub(code, 0, signalPosition)
        + connectLine + "\r\n\r\n"
        + str.sub(code, signalPosition);
}

root.code.text = code;

file.write(path, json.stringify(root, true), file.ENC_UTF8_BOM);
print("thumbLabel: URL карточки кликабелен с миниатюрой и без неё");
return 0;
