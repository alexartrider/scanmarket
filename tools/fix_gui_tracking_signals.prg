// Переносит сигналы GUI на верхний уровень модуля формы.
var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

var path = "scanmarket_gui.json";
var source = file.read(path, file.ENC_UTF8_BOM);

if (source == null or source == "")
    throw "Не удалось прочитать scanmarket_gui.json";

var root = json.parse(source);

if (root == null)
    throw "Не удалось разобрать scanmarket_gui.json";

var code = str.toString(root.code.text);
var buttonSignal = "form.trackingButton.clicked = trackingButton_clicked;";
var thumbSignal = "form.thumbLabel.linkActivated = thumbLabel_linkActivated;";
if (str.pos(code, "function trackingButton_clicked(Sender, checked)") < 0)
    throw "Не найден обработчик кнопки отслеживания";

if (str.pos(code, "function thumbLabel_linkActivated(Sender, href)") < 0)
    throw "Не найден обработчик ссылки миниатюры";

code = str.replace(code, buttonSignal, "");
code = str.replace(code, thumbSignal, "");

code = str.rtrim(code)
    + "\r\n\r\n"
    + thumbSignal + "\r\n"
    + buttonSignal + "\r\n";

root.code.text = code;
file.write(path, json.stringify(root, true), file.ENC_UTF8_BOM);

print("Сигналы кнопки и ссылки подключены на верхнем уровне формы");
return 0;
