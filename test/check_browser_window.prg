// Одноразовая диагностика/активация окна браузера проекта через CDP.
var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
projectDir = file.dirname(projectDir);
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/cdp.prg");

var version = versionInfo(9222);
if (version == null) {
    print("DevTools недоступны на порту 9222");
    return 1;
}

var targets = listTargets(9222);
if (targets == null) {
    print("Не удалось прочитать список вкладок");
    return 1;
}

var target = null;
for (var item : targets) {
    if (str.pos(str.lower(coalesce(item.get("url"), "")), "market.yandex.ru") >= 0) {
        target = item;
        break;
    }
}

if (target == null) {
    print("Вкладка Яндекс Маркета не найдена");
    return 1;
}

var browser = CdpClient();
if (!browser.connect(coalesce(version.get("webSocketDebuggerUrl"), ""))) {
    print("Не удалось подключиться к browser websocket");
    return 1;
}

var window = browser.call("Browser.getWindowForTarget", #{"targetId": target.get("id")});
if (window == null) {
    print("Browser.getWindowForTarget: " + coalesce(browser.lastError, "ошибка"));
    browser.closeconn();
    return 1;
}

var windowId = window.get("windowId");
var bounds = window.get("bounds");
print("URL: " + coalesce(target.get("url"), ""));
print("windowId=" + str.toString(windowId) + ", bounds=" + json.stringify(bounds));

var shown = browser.call(
    "Browser.setWindowBounds",
    #{"windowId": windowId, "bounds": #{"left": 40, "top": 40, "width": 1400, "height": 900, "windowState": "normal"}}
);
if (shown == null) {
    print("Не удалось показать окно: " + coalesce(browser.lastError, "ошибка"));
    browser.closeconn();
    return 1;
}

system.sleep(0.5);
shown = browser.call(
    "Browser.setWindowBounds",
    #{"windowId": windowId, "bounds": #{"windowState": "maximized"}}
);
if (shown == null) {
    print("Окно восстановлено, но не удалось развернуть: " + coalesce(browser.lastError, "ошибка"));
    browser.closeconn();
    return 1;
}

browser.closeconn();
print("Команды активации окна отправлены");
return 0;
