// cdp.prg — управление браузером (Edge/Chrome) через Chrome DevTools Protocol
// Обращение: var cdp = loadModule("lib/cdp.prg");

loadPlugin(file.join(file.programpath(), "plugins", "http.dll"));
loadPlugin(file.join(file.programpath(), "plugins", "websocket.dll"));

var http = HttpClient();
// локальные запросы без системного прокси (иначе 127.0.0.1 может идти через 127.0.0.1:7897)
try { http.setProxy("", 0); } catch (e) { }
// жёсткий таймаут: иначе get к живому DevTools зависает навсегда
try { http.setTimeout(3000); } catch (e) { }
var psTmpFile = coalesce(file.getenv("TEMP"), "data") + "\\cdp_http.tmp";
var debugPort = 9222;
var profileDir = file.absolute(file.join("private_data", "browser_profile"));
var browserPath = "";

function consoleStateSummary(state) {
    if (state == null or !state.istuple()) return "состояние недоступно";
    return "подключена=" + str.toString(coalesce(state.get("attached"), false))
        + ", stdout-консоль=" + str.toString(coalesce(state.get("stdoutIsConsole"), false))
        + ", stderr-консоль=" + str.toString(coalesce(state.get("stderrIsConsole"), false))
        + ", перенаправлен вывод=" + str.toString(coalesce(state.get("outputRedirected"), false))
        + ", обработка перевода строк=" + str.toString(coalesce(state.get("processedOutput"), false))
        + ", VT=" + str.toString(coalesce(state.get("vtProcessing"), false))
        + ", ANSI=" + str.toString(coalesce(state.get("ansiColorsEnabled"), false))
        + ", восстановление успешно=" + str.toString(coalesce(state.get("refreshSucceeded"), false))
        + ", ошибка WinAPI=" + str.toString(coalesce(state.get("lastError"), 0));
}

function cdpSetup(port, profilePath, execPath) export {
    if (port != null) debugPort = port;
    if (profilePath != null) profileDir = file.absolute(profilePath);
    if (execPath != null and execPath != "") {
        if (file.exists(execPath)) browserPath = file.absolute(execPath);
        else error("browser.execPath не найден: \(execPath) — использую автоопределение");
    }
}

// Поиск установленного браузера (Yandex — основной)
function findBrowser() export {
    if (browserPath != "" and file.exists(browserPath)) return browserPath;
    var pf86 = coalesce(file.getenv("ProgramFiles(x86)"), "C:\\Program Files (x86)");
    var pf = coalesce(file.getenv("ProgramFiles"), "C:\\Program Files");
    var lad = coalesce(file.getenv("LOCALAPPDATA"), "");
    var candidates = #[
        file.join(pf, "Yandex", "YandexBrowser", "Application", "browser.exe"),
        file.join(pf86, "Yandex", "YandexBrowser", "Application", "browser.exe"),
        file.join(pf86, "Microsoft", "Edge", "Application", "msedge.exe"),
        file.join(pf, "Microsoft", "Edge", "Application", "msedge.exe"),
        file.join(pf86, "Google", "Chrome", "Application", "chrome.exe"),
        file.join(pf, "Google", "Chrome", "Application", "chrome.exe"),
        file.join(lad, "Google", "Chrome", "Application", "chrome.exe")
    ];
    for (var p : candidates) {
        if (file.exists(p)) return p;
    }
    return null;
}

// Количество живых процессов браузера с нашим профилем (-1 — WMI недоступен)
function profileProcCount() {
    var procs = null;
    try { procs = system.wmi.processes(); } catch (e) { procs = null; }
    if (procs == null) return -1;
    var marker = str.lower(file.basename(profileDir));
    var n = 0;
    for (var p : procs) {
        var nm = str.lower(coalesce(p.Name, ""));
        var cl = str.lower(coalesce(p.CommandLine, ""));
        if ((nm == "msedge.exe" or nm == "chrome.exe" or nm == "browser.exe") and str.pos(cl, marker) >= 0) n++;
    }
    return n;
}

// Закрыть прошлый браузер с нашим профилем.
// Сначала мягко (Browser.close — сессия сбрасывается на диск), принудительно — только в крайнем случае.
function stopExisting() export {
    var count = profileProcCount();
    if (count < 0) {
        print("Список процессов недоступен — пропускаю закрытие");
        return 0;
    }
    if (count == 0) return 0;
    print("Работает браузер проекта (\(str.toString(count)) проц.) — корректное закрытие...");
    closeBrowser(debugPort);
    var deadline = system.gettickcount() + 10000;
    while (system.gettickcount() < deadline) {
        count = profileProcCount();
        if (count <= 0) {
            print("Браузер закрыт корректно — сессия сохранена");
            return 1;
        }
        system.sleep(0.5);
    }
    // жёсткое закрытие — теряет несброшенную сессию; избегаем принудительного завершения системных процессов
    print("Корректное закрытие не сработало, завершаю процессы принудительно...");
    var procs = null;
    try { procs = system.wmi.processes(); } catch (e) { procs = null; }
    if (procs != null) {
        var marker = str.lower(file.basename(profileDir));
        for (var p : procs) {
            var nm = str.lower(coalesce(p.Name, ""));
            var cl = str.lower(coalesce(p.CommandLine, ""));
            if ((nm == "msedge.exe" or nm == "chrome.exe" or nm == "browser.exe") and str.pos(cl, marker) >= 0) {
                system.system("powershell -NoProfile -Command \"Stop-Process -Id " + str.toString(p.ProcessId) + " -Force -ErrorAction SilentlyContinue\"");
            }
        }
    }
    system.sleep(2);
    print("Браузер закрыт принудительно — вход мог сброситься, при необходимости запустите ozon_auth.prg");
    return 1;
}

// Запуск браузера с профилем и портом DevTools
function openBrowser(headless, startUrl, proxyMode, startMinimized) export {
    var exe = findBrowser();
    if (exe == null) throw "Не найден браузер (Edge/Chrome/Yandex). Укажите browser.execPath в config.json";
    var a = #[
        exe,
        "--user-data-dir=" + profileDir,
        "--remote-debugging-port=" + str.toString(debugPort),
        "--no-first-run",
        "--no-default-browser-check",
        "--start-maximized",
        "--disable-backgrounding-occluded-windows",
        "--disable-background-timer-throttling",
        "--disable-renderer-backgrounding",
        "--window-size=1600,1000"
    ];
    if (headless) a.push("--headless=new", "--mute-audio", "--hide-scrollbars");
    if (startMinimized == true) a.push("--start-minimized");
    if (proxyMode != null and proxyMode != "") {
        if (proxyMode == "direct") a.push("--proxy-bypass-list=*");
        else a.push("--proxy=" + proxyMode);
    }
    if (startUrl != null and startUrl != "") a.push(startUrl);
    // Не выводим всю командную строку браузера одной строкой: длинные флаги
    // Chromium переполняют ширину консоли и портят отображение следующих логов.
    print("Запуск браузера: \(exe)");
    print("Профиль браузера: \(profileDir)");
    print("Порт DevTools: \(str.toString(debugPort))");
    if (startUrl != null and startUrl != "") print("Начальная страница: \(startUrl)");

    // Снимок до запуска нужен, чтобы сравнивать фактическое состояние консоли.
    try {
        print("Консоль до запуска браузера: \(consoleStateSummary(Log.consoleInfo()))");
    } catch (e) {
        print("Не удалось получить состояние консоли перед запуском браузера: \(str.toString(e))");
    }

    // Передаём executable и аргументы отдельно: systemasync(cmd) запускает
    // командную строку через оболочку, а profileDir и URL могут содержать
    // пробелы. execArgvAsync сохраняет аргументы и отсоединяет GUI от консоли.
    var proc = system.execArgvAsync(a, #{"timeout": 86400000, "console": "detached"});

    return proc;
}

// HTTP к DevTools: http-плагин с резервным путём через curl.exe
function devtoolsHttp(method, url) {
    var ok = false;
    try {
        if (method == "PUT") ok = http.put(url);
        else if (method == "DELETE") ok = http.del(url);
        else if (method == "POST") ok = http.get(url);
        else ok = http.get(url);
    } catch (e) { ok = false; }
    if (ok) {
        var st = http.status();
        if (st >= 200) {
            if (st < 400) {
                var body = coalesce(http.getResponse(), "");
                if (body != "") return body;
            }
        }
    }
    // резервный путь через curl.exe (не зависит от прокси/таймаутов плагина)
    var methodFlag = "";
    if (method == "PUT") methodFlag = "-X PUT ";
    if (method == "DELETE") methodFlag = "-X DELETE ";
    if (method == "POST") methodFlag = "-X POST ";
    var cmd = "curl.exe " + methodFlag + "-s -m 8 \"" + url + "\" -o \"" + psTmpFile + "\"";
    try { file.remove(psTmpFile); } catch (e) { }
    system.system(cmd);
    if (!file.exists(psTmpFile)) return null;
    var text = null;
    var seq = #[file.ENC_UTF8_NO_BOM, file.ENC_UTF8_BOM, null];
    for (var enc : seq) {
        try {
            if (enc == null) text = file.read(psTmpFile);
            else text = file.read(psTmpFile, enc);
        } catch (e) { text = null; }
        if (text != null) break;
    }
    if (text == null) return null;
    if (text == "") return null;
    return text;
}

function versionInfo(port) export {
    if (port == null) port = debugPort;
    var t = devtoolsHttp("GET", "http://127.0.0.1:" + str.toString(port) + "/json/version");
    if (t == null) return null;
    var r = null;
    try { r = json.parse(t); } catch (e) { return null; }
    return r;
}

// Ожидание, пока DevTools-порт начнёт отвечать
function waitForDevTools(port, timeoutSeconds) export {
    if (port == null) port = debugPort;
    var deadline = system.gettickcount() + timeoutSeconds * 1000;
    var lastLog = 0;
    var started = system.gettickcount();
    while (system.gettickcount() < deadline) {
        if (versionInfo(port) != null) {
            // Браузер уже запущен и DevTools отвечает. Восстанавливаем режим
            // консоли непосредственно перед первым сообщением после его старта:
            // ранний вызов сразу после CreateProcessW мог произойти до того,
            // как браузер или его дочерние процессы изменили режим общей консоли.
            try {
                var consoleState = Log.refreshConsole();
                print("Консоль после запуска браузера: \(consoleStateSummary(consoleState))");
            } catch (e) {
                print("Не удалось восстановить консоль после запуска браузера: \(str.toString(e))");
            }
            print("DevTools отвечает (ожидание \(str.toString((system.gettickcount() - started) / 1000.0)) сек)");
            return true;
        }
        if (system.gettickcount() - lastLog > 5000) {
            lastLog = system.gettickcount();
            print("Ожидание DevTools: \(str.toString((system.gettickcount() - started) / 1000.0)) сек из \(str.toString(timeoutSeconds))");
        }
        system.sleep(0.5);
    }
    return false;
}

function listTargets(port) export {
    if (port == null) port = debugPort;
    var t = devtoolsHttp("GET", "http://127.0.0.1:" + str.toString(port) + "/json/list");
    if (t == null) return null;
    var r = null;
    try { r = json.parse(t); } catch (e) { return null; }
    if (r == null) return null;
    if (!r.isarray()) return null;
    return r;
}

function findTarget(port, urlPart, titlePart) export {
    if (port == null) port = debugPort;
    var list = listTargets(port);
    if (list == null) return null;
    var part = (urlPart == null) ? "" : str.lower(urlPart);
    var tPart = (titlePart == null) ? "" : str.lower(titlePart);
    for (var t : list) {
        if (!t.istuple()) continue;
        if (t.get("type") != "page") continue;
        var u = str.lower(coalesce(t.get("url"), ""));
        if (part != "") {
            var found = str.pos(u, part);
            if (found < 0) continue;
        }
        if (tPart != "") {
            var title = str.lower(coalesce(t.get("title"), ""));
            var found2 = str.pos(title, tPart);
            if (found2 < 0) continue;
        }
        return t;
    }
    return null;
}

// Открыть новую вкладку (PUT /json/new, для старых версий — GET)
function openTab(port, url) export {
    if (port == null) port = debugPort;
    var u = "http://127.0.0.1:" + str.toString(port) + "/json/new?" + http.urlEncode(url);
    var t = devtoolsHttp("PUT", u);
    if (t == null) t = devtoolsHttp("GET", u);
    if (t == null) return null;
    var r = null;
    try { r = json.parse(t); } catch (e) { return null; }
    return r;
}

// WebSocket-клиент CDP
class CdpClient {
    var ws;
    var nextId;
    var lastError;

    CdpClient() {
        this.ws = WebSocket();
        this.nextId = 10;
        this.lastError = "";
    }

    function connect(url) {
        var ok = this.ws.connect(url);
        if (!ok) {
            this.lastError = coalesce(this.ws.lastError(), "ошибка подключения");
            return false;
        }
        this.ws.setTimeout(300);
        return true;
    }

    // Вызов метода CDP: отправка и ожидание ответа с этим id (события пропускаются)
    function call(method, params) {
        if (!this.ws.isconnected()) {
            this.lastError = "соединение закрыто";
            return null;
        }
        this.nextId++;
        var id = this.nextId;
        var paramsJson = "";
        if (params != null) {
            if (params.isstring()) paramsJson = str.toString(params);
            else paramsJson = json.stringify(params);
        }
        if (paramsJson == "") paramsJson = "{}";
        var msg = "{\"id\":" + str.toString(id) + ",\"method\":" + json.stringify(method) + ",\"params\":" + paramsJson + "}";
        if (!this.ws.send(msg)) {
            this.lastError = coalesce(this.ws.lastError(), "ошибка отправки");
            return null;
        }
        var tag = "\"id\":" + str.toString(id) + ",";
        var deadline = system.gettickcount() + 20000;
        while (system.gettickcount() < deadline) {
            var txt = this.ws.recv();
            if (txt == null) {
                if (!this.ws.isconnected()) {
                    this.lastError = coalesce(this.ws.lastError(), "соединение закрыто");
                    return null;
                }
                continue;
            }
            if (str.pos(txt, tag) < 0) continue;
            var parsed = null;
            try { parsed = json.parse(txt); } catch (e) { continue; }
            if (parsed == null) continue;
            if (!parsed.istuple()) continue;
            if (parsed.get("id") != id) continue;
            if (parsed.has("error")) {
        print("CDP вернул ошибку: \(txt)");
                this.lastError = "cdp error";
                var er = parsed.get("error");
                if (er.istuple()) {
                    if (er.has("message")) {
                        var em = er.get("message");
                        if (em != null) this.lastError = str.toString(em);
                    }
                }
                return null;
            }
            return parsed.get("result");
        }
        this.lastError = "timeout";
        return null;
    }

    // Выполнить JS на странице, вернуть значение
    function evaluate(expr) {
    // в Script нет bool (только 0/1), а CDP ждёт литерал true — не передаём returnByValue;
    // для примитивов value возвращается в RemoteObject и так
    var r = this.call("Runtime.evaluate", #{"expression": expr});
        if (r == null) return null;
        var rr = r.get("result");
        if (rr == null) return null;
        return rr.get("value");
    }

    function closeconn() {
        try { this.ws.close(); } catch (e) {
            try { this.ws.disconnect(); } catch (e2) { }
        }
    }
}

function currentPageLowerUrl(page) export {
    if (page == null) return "";
    var u = evalStr(page, "document.location.href");
    if (u == null) return "";
    return str.lower(str.toString(u));
}

function pageAlive(page) export {
    if (page == null) return false;
    var v = evalStr(page, "1");
    return (v == "1");
}

function closeConnSafely(p) export {
    if (p == null) return;
    try { p.closeconn(); } catch (e) { }
}

// Подключиться к вкладке-странице
function attachToPage(target) export {
    if (target == null) return null;
    var url = coalesce(target.get("webSocketDebuggerUrl"), "");
    if (url == "") {
        print("CDP: у вкладки отсутствует адрес WebSocket для подключения.");
        return null;
    }
    var page = CdpClient();
    var perr0 = coalesce(page.lastError, "");
    if (!page.connect(url)) {
        print("CDP: не удалось подключиться по WebSocket: \(perr0)");
        return null;
    }
    print("CDP: подключение к вкладке установлено.");
    return page;
}

function getCookies(page) export {
    // #{} пустое = множество (type 7), json.stringify его как [] — CDP ждёт object;
    if (page == null) return null;
    var r = page.call("Network.getAllCookies", "{}");
    if (r == null) return null;
    return r.get("cookies");
}

function findOzonTarget(port) export {
    var t = findTarget(port, "my/favorites", null);
    if (t != null) return t;
    return findTarget(port, "ozon.ru", null);
}

function findWildberriesTarget(port) export {
    var t = findTarget(port, "lk/favorites", null);
    if (t != null) return t;
    return findTarget(port, "wildberries.ru", null);
}

function reconnectFavorites(port, favUrl) export {
    var t = findOzonTarget(port);
    if (t == null) {
        t = openTab(port, favUrl);
        system.sleep(2);
        t = findOzonTarget(port);
    }
    if (t == null) return null;
    return attachToPage(t);
}

// Подключается к вкладке Wildberries, не порождая лишние вкладки:
// сначала ищет вкладку WB, иначе берёт любую существующую страницу
// и переходит по favUrl; новую вкладку открывает только если страниц нет.
function reconnectWildberries(port, favUrl) export {
    var t = findWildberriesTarget(port);
    if (t != null)
        return attachToPage(t);

    var anyTab = findTarget(port, "", null);
    if (anyTab != null) {
        var p = attachToPage(anyTab);
        if (p != null) {
            navigate(p, favUrl);
            return p;
        }
    }

    t = openTab(port, favUrl);
    system.sleep(2);
    t = findWildberriesTarget(port);
    if (t == null) return null;
    return attachToPage(t);
}

function findYandexMarketTarget(port) export {
    var t = findTarget(port, "my/wishlist", null);
    if (t != null) return t;
    return findTarget(port, "market.yandex.ru", null);
}

// Показывает и активирует окно браузера для выбранной вкладки.
// На Windows detached-запуск иногда оставляет окно свёрнутым/за другими окнами.
function showTargetWindow(target) export {
    if (target == null) return false;

    var version = versionInfo(debugPort);
    if (version == null) {
        print("Не удалось получить browser websocket для показа окна.");
        return false;
    }

    var browserUrl = coalesce(version.get("webSocketDebuggerUrl"), "");
    if (browserUrl == "") {
        print("В browser websocket отсутствует адрес подключения.");
        return false;
    }

    var browser = CdpClient();
    if (!browser.connect(browserUrl)) {
        print("Не удалось подключиться к browser websocket: " + coalesce(browser.lastError, ""));
        return false;
    }

    var targetId = coalesce(target.get("id"), "");
    if (targetId == "") {
        browser.closeconn();
        print("У вкладки отсутствует target id — окно не активировано.");
        return false;
    }

    var windowInfo = browser.call("Browser.getWindowForTarget", #{"targetId": targetId});
    if (windowInfo == null) {
        print("Browser.getWindowForTarget завершился ошибкой: " + coalesce(browser.lastError, ""));
        browser.closeconn();
        return false;
    }

    var windowId = windowInfo.get("windowId");
    var bounds = #{
        "windowId": windowId,
        "bounds": #{"left": 40, "top": 40, "width": 1400, "height": 900, "windowState": "normal"}
    };
    var restored = browser.call("Browser.setWindowBounds", bounds);
    if (restored == null) {
        print("Не удалось восстановить окно браузера: " + coalesce(browser.lastError, ""));
        browser.closeconn();
        return false;
    }

    var maximized = browser.call(
        "Browser.setWindowBounds",
        #{"windowId": windowId, "bounds": #{"windowState": "maximized"}}
    );
    browser.closeconn();

    var page = attachToPage(target);
    if (page != null) {
        page.call("Page.bringToFront", "{}");
        closeConnSafely(page);
    }

    if (maximized == null) {
        print("Окно восстановлено, но не удалось развернуть его: " + coalesce(browser.lastError, ""));
        return false;
    }

    print("Окно браузера восстановлено и вкладка выведена на передний план.");
    return true;
}

// Подключается к вкладке Яндекс Маркета, не порождая лишние вкладки:
// сначала ищет вишлист, иначе берёт любую существующую страницу и переходит
// по favUrl; новую вкладку открывает только если страниц нет.
function reconnectYandexMarket(port, favUrl) export {
    var t = findYandexMarketTarget(port);
    if (t != null)
        return attachToPage(t);

    var anyTab = findTarget(port, "", null);
    if (anyTab != null) {
        var p = attachToPage(anyTab);
        if (p != null) {
            navigate(p, favUrl);
            return p;
        }
    }

    t = openTab(port, favUrl);
    system.sleep(2);
    t = findYandexMarketTarget(port);
    if (t == null) return null;
    return attachToPage(t);
}

function refreshFavorites(page, port, favUrl) export {
    if (page != null) {
        var lower = currentPageLowerUrl(page);
        if (str.pos(lower, "/login") >= 0) return null;
        navigate(page, favUrl);
        closeConnSafely(page);
    }
    return reconnectFavorites(port, favUrl);
}

// Не перезагружает живую страницу избранного: повторная навигация сбрасывает
// ручную авторизацию и может повторно вызвать антибот-проверку. Переподключение
// выполняется только после потери CDP-соединения.
function refreshFavoritesForce(page, port, favUrl) export {
    if (page != null and pageAlive(page))
        return page;

    closeConnSafely(page);
    return reconnectFavorites(port, favUrl);
}

// Для Wildberries сохраняет живую страницу без навигации: антибот-защита
// реагирует на повторные перезагрузки. Переподключение делаем только
// при потере CDP-соединения.
function refreshWildberriesForce(page, port, favUrl) export {
    if (page != null and pageAlive(page)) {
        return page;
    }
    closeConnSafely(page);
    return reconnectWildberries(port, favUrl);
}

function waitPageComplete(page, timeoutSeconds) export {
    if (timeoutSeconds == null) timeoutSeconds = 25;
    if (page == null) return false;
    print("Загрузка страницы (лимит " + str.toString(timeoutSeconds) + " сек)...");
    var deadline = system.gettickcount() + timeoutSeconds * 1000;
    var started = system.gettickcount();
    var st = "";
    while (system.gettickcount() < deadline) {
        st = coalesce(page.evaluate("document.readyState"), "");
        if (st == "complete") {
            print("Страница загружена за " + str.toString((system.gettickcount() - started) / 1000.0) + " сек");
            return true;
        }
        if (system.gettickcount() - started > 5000) {
            if (str.len(st) == 0) {
                print("  Состояние загрузки страницы не получено; последняя ошибка: " + coalesce(page.lastError, "нет"));
                system.sleep(4);
            }
        }
        system.sleep(0.5);
    }
    print("Страница не дождалась readyState=complete, текущее состояние: " + st);
    return false;
}

// Прокрутка страницы вниз для догрузки ленивых блоков
function scrollPage(page, steps) export {
    if (steps == null) steps = 5;
    if (page == null) return false;
    print("Прокрутка страницы для догрузки карточек (" + str.toString(steps) + " шагов)...");
    for (var i = 0; i < steps; i++) {
        page.evaluate("window.scrollBy(0, document.documentElement.clientHeight)");
        system.sleep(1);
        print("  прокрутка " + str.toString(i + 1) + "/" + str.toString(steps));
    }
    page.evaluate("window.scrollTo(0, 0)");
    system.sleep(0.5);
    print("Прокрутка завершена");
}

// Переход страницы по URL
function navigate(page, url) export {
    if (page == null) return false;
    var r = page.call("Page.navigate", #{"url": url});
    if (r == null) {
        print("CDP: навигация не удалась: " + coalesce(page.lastError, ""));
        return false;
    }
    return true;
}

// Сохранить куки страницы в файл (private_data/<store>/<store>_cookies.json)
function saveCookiesToFile(page, path) export {
    if (page == null or path == null or path == "") return false;
    var cookies = getCookies(page);
    var ok = (cookies != null);
    if (ok) ok = (!cookies.empty());
    if (!ok) {
        print("Куки не получены — файл не пишу");
        return false;
    }
    file.mkdirrecursive(file.dirname(path));
    file.write(path, json.stringify(cookies, true), file.ENC_UTF8_BOM);
    print("Куки сохранены: " + path + " (" + str.toString(cookies.size()) + " шт.)");
    return true;
}

// JSON-литерал bool: 1 -> "true", иначе "false" (в Script нет bool, CDP требует литералы)
function boolLit(v) {
    var t = false;
    if (v != null) t = (v == 1);
    if (t) return "true";
    return "false";
}

// Восстановить куки из файла в браузер; возвращает количество или 0.
// defaultDomain — домен для записей без собственного поля domain
// (для Ozon ".ozon.ru", для Wildberries ".wildberries.ru").
function restoreCookiesFromFile(page, path, defaultDomain) export {
    if (page == null or path == null or path == "") return 0;
    if (defaultDomain == null or defaultDomain == "") defaultDomain = ".ozon.ru";
    var raw = null;
    try { raw = file.read(path, file.ENC_UTF8_BOM); } catch (e) { raw = null; }
    if (raw == null) {
        try { raw = file.read(path); } catch (e) { raw = null; }
    }
    if (raw == null or raw == "") {
        print("Файл куки пуст или не читается: " + path);
        return 0;
    }
    // обрезаем BOM, если остался (json.parse его не терпит); fromCharCode нет — через str.ord
    if (str.len(raw) > 0) {
        var ch0 = str.sub(raw, 0, 1);
        if (str.ord(ch0) == 65279) raw = str.sub(raw, 1);
    }
    var list = null;
    try { list = json.parse(str.trim(raw)); } catch (e) { list = null; }
    if (list == null) {
        print("Файл куки повреждён: " + path);
        return 0;
    }
    var isArray = list.isarray();
    if (!isArray) {
        print("Файл куки повреждён: " + path);
        return 0;
    }
    // оставляем только поля, которые принимает Network.setCookies.
    // #{} пустое = множество — строим JSON прямо в одном цикл
    var parts = #[];
    for (var c : list) {
        var okC = (c != null);
        if (okC) okC = c.istuple();
        if (!okC) continue;
        var nm = c.get("name");
        var vl = c.get("value");
        if (nm == null or vl == null) continue;
        var one = "{";
        one = one + "\"name\":" + json.stringify(str.toString(nm));
        one = one + ",\"value\":" + json.stringify(str.toString(vl));
        one = one + ",\"domain\":" + json.stringify(str.toString(coalesce(c.get("domain"), defaultDomain)));
        one = one + ",\"path\":" + json.stringify(str.toString(coalesce(c.get("path"), "/")));
        one = one + ",\"secure\":" + boolLit(c.get("secure"));
        one = one + ",\"httpOnly\":" + boolLit(c.get("httpOnly"));
        if (c.has("expires")) {
            var ex = c.get("expires");
            if (ex != null) one = one + ",\"expires\":" + str.toString(ex);
        }
        if (c.has("sameSite")) {
            var ss = c.get("sameSite");
            if (ss != null) one = one + ",\"sameSite\":" + json.stringify(str.toString(ss));
        }
        if (c.has("priority")) {
            var pr = c.get("priority");
            if (pr != null) one = one + ",\"priority\":" + json.stringify(str.toString(pr));
        }
        one = one + "}";
        parts.push(one);
    }
    var paramsJson = "{\"cookies\":[" + parts.joined(",") + "]}";
    if (parts.empty()) {
        print("В файле куки нет подходящих записей");
        return 0;
    }
    var r = page.call("Network.setCookies", paramsJson);
    if (r == null) {
        print("Куки не установлены: " + coalesce(page.lastError, ""));
        return 0;
    }
    print("Куки восстановлены: " + str.toString(parts.size()) + " шт.");
    return parts.size();
}

// Закрыть весь браузер
function closeBrowser(port) export {
    if (port == null) port = debugPort;
    var v = versionInfo(port);
    if (v == null) return false;
    var wsurl = coalesce(v.get("webSocketDebuggerUrl"), "");
    if (wsurl == "") return false;
    var b = CdpClient();
    if (!b.connect(wsurl)) return false;
    b.call("Browser.close", "{}");
    b.closeconn();
    print("Браузер закрыт");
    return true;
}

// evaluate строки: null = плагин не отвечает (lastError заполнен)
function evalStr(page, js) export {
    if (page == null) return null;
    var r = page.evaluate(js);
    if (r == null) return null;
    if (!r.isstring()) return str.toString(r);
    return str.toString(r);
}

function pageTitle(page) export {
    var t = evalStr(page, "document.title");
    if (t == null) return "";
    return str.toString(t);
}

// HTML страницы к дамп файлу
function dumpPageHtml(page, path, chunkSize) export {
    if (chunkSize == null) chunkSize = 40000;
    if (page == null or path == null or path == "") return -1;
    var first = evalStr(page, "(function(){if(!window.__qdumphtml)window.__qdumphtml=document.documentElement.outerHTML;var s=window.__qdumphtml;var b=" + str.toString(chunkSize) + ";if(b>s.length)b=s.length;return s.substring(0,b);})()");
    if (first == null) {
        print("Не удалось получить первую часть HTML: " + coalesce(page.lastError, "неизвестная ошибка"));
        return -1;
    }
    var st0 = str.toString(first);
    var n = str.len(st0);
    if (n == 0) return 0;
    file.write(path, st0, file.ENC_UTF8_NO_BOM);
    var pos = n;
    while (pos > 0 and pos < n + 5000000) {
        var js = "(function(){if(!window.__qdumphtml)window.__qdumphtml=document.documentElement.outerHTML;var s=window.__qdumphtml;var a=" + str.toString(pos) + ";var b=a+" + str.toString(chunkSize) + ";if(b>s.length)b=s.length;return s.substring(a,b);})()";
        var c = evalStr(page, js);
        if (c == null) {
            print("Не удалось получить часть HTML: " + coalesce(page.lastError, "неизвестная ошибка"));
            break;
        }
        var cs = str.toString(c);
        if (str.len(cs) == 0) break;
        file.append(path, cs, file.ENC_UTF8_NO_BOM);
        pos = pos + str.len(cs);
        if ((pos / chunkSize) % 10 == 0) print("Сохранено символов HTML: " + str.toString(pos));
    }
    print("Дамп HTML сохранён: " + path + " (символов: " + str.toString(pos) + ").");
    return pos;
}
