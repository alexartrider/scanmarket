// Read-only structural check for the GUI script and clickable thumbnail.
var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

var root = json.parse(file.read("scanmarket_gui.json", file.ENC_UTF8_BOM));
if (root == null)
    throw "GUI JSON parse failed";

var code = root.get("code").get("text");

if (code == null or str.len(code) < 1000)
    throw "GUI code.text is empty or truncated";

if (str.pos(code, "thumbBytes.base64()") < 0)
    throw "thumbnail HTML image missing";

if (str.pos(code, "from products ") < 0)
    throw "products SELECT missing";

if (str.pos(code, "function thumbLabel_linkActivated(Sender, href)") < 0)
    throw "thumbnail link handler missing";

if (str.pos(code, "form.thumbLabel.linkActivated = thumbLabel_linkActivated;") < 0)
    throw "thumbnail link signal is not connected";

var showProductPosition = str.pos(code, "function showProduct(rowIndex)");
var buttonHandlerPosition = str.pos(code,
    "function trackingButton_clicked(Sender, checked)");
var buttonSignalPosition = str.pos(code,
    "form.trackingButton.clicked = trackingButton_clicked;");
var rowHandlerPosition = str.pos(code,
    "function productsGrid_currentRowChanged(Sender, rowIndex)");
var thumbnailHandlerPosition = str.pos(code,
    "function thumbLabel_linkActivated(Sender, href)");
var thumbnailSignalPosition = str.pos(code,
    "form.thumbLabel.linkActivated = thumbLabel_linkActivated;");
var codeLength = str.len(code);

if (thumbnailHandlerPosition > showProductPosition)
    throw "thumbnail link handler must be declared before showProduct";

if (buttonSignalPosition < buttonHandlerPosition or
    thumbnailSignalPosition < thumbnailHandlerPosition or
    buttonSignalPosition > codeLength or thumbnailSignalPosition > codeLength)
    throw "widget signals must follow their handler declarations";

if (str.pos(code, "form.thumbLabel.textFormat = 2;") < 0)
    throw "QLabel is not configured for rich text links";

if (str.pos(code, "form.thumbLabel.textInteractionFlags = 4;") < 0)
    throw "mouse link interaction is not enabled";

if (str.pos(code, "if (currentUrl != \"\")") < 0)
    throw "product URL guard missing";

if (str.pos(code, "thumbBytes != null") < 0)
    throw "thumbnail null check missing";

if (str.pos(code, "width=\\\"96\\\" height=\\\"96\\\"") < 0)
    throw "96x96 image dimensions missing";

if (str.pos(code, "imageHtml = imageHtml + \"Нет фото\"") < 0)
    throw "clickable no-image placeholder missing";

if (str.pos(code, "form.openOzon") >= 0)
    throw "reference to removed openOzon button remains";

if (str.pos(code, "function trackingButton_clicked(Sender, checked)") < 0)
    throw "tracking button handler missing";

if (str.pos(code, "form.trackingButton.clicked = trackingButton_clicked;") < 0)
    throw "tracking button signal is not connected";

if (str.count(code, "form.trackingButton.clicked = trackingButton_clicked;") != 1)
    throw "tracking button signal must be connected once";

if (str.count(code, "form.thumbLabel.linkActivated = thumbLabel_linkActivated;") != 1)
    throw "thumbnail link signal must be connected once";

if (str.pos(code, "currentTrackingEnabled = (q.field(6) != 0);") < 0)
    throw "tracking state is not read for selected product";

if (str.pos(code, "set tracking_enabled = ? where source = 'ozon' and product_id = ?") < 0)
    throw "tracking button does not update the selected product";

if (str.pos(code, "\u0414\u0418\u041d\u0410\u041c\u0418\u041a\u0410 \u0426\u0415\u041d") < 0)
    throw "Russian chart text not intact";

function countTrackingButtons(widgets)
{
    var count = 0;

    if (widgets == null)
        return count;

    for (var widget : widgets)
    {
        if (str.toString(coalesce(widget.get("name"), "")) == "trackingButton")
            count++;

        count = count + countTrackingButtons(widget.get("children"));
    }

    return count;
}

var buttonCount = countTrackingButtons(root.get("form").get("widgets"));

if (buttonCount != 1)
    throw "tracking button must exist exactly once in the form";

print("GUI JSON: thumbnail, click link and tracking button verified; chars=" + str.toString(str.len(code)));
return 0;
