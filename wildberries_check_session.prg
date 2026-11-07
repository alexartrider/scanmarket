// Проверка: открывает профиль в браузере (Yandex/Edge/Chrome),
// доходит до «Избранного» Wildberries и: если сессия жива — сохраняет куки
// в private_data/wildberries/wildberries_cookies.json,
// иначе пишет «нужен вход» (запустить wildberries_auth.prg).
var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/wildberries.prg");

var cfg = loadConfig("");

function main() {
    var port = cfgGet(cfg, "browser.debugPort", 9222);
    var profile = cfgGet(cfg, "browser.profileDir", "private_data/browser_profile");
    var favUrl = cfgGet(cfg, "wildberries.favoritesUrl", "https://www.wildberries.ru/lk/favorites");

    cdpSetup(port, profile, cfgGet(cfg, "browser.execPath", ""));
    print("Браузер: " + coalesce(findBrowser(), "не найден"));
    var existingWb = findWildberriesTarget(port);

    if (existingWb == null) {
        var profileProcesses = profileProcCount();
        if (profileProcesses > 0) {
            error("Браузер проекта уже открыт, но вкладка Wildberries не найдена. " +
                "Не запускаю второй браузер, чтобы не плодить окна и вкладки.");
            system.exit(1);
        }

        print("Открываю профиль...");
        openBrowser(false, favUrl, cfgGet(cfg, "browser.proxy", ""));
        if (!waitForDevTools(port, 60)) {
            error("DevTools не поднялись за 60 сек");
            system.exit(1);
        }
    }

    // ищем вкладку wildberries
    var target = null;
    var deadline = system.gettickcount() + 120000;
    var lastLog = system.gettickcount();
    while (system.gettickcount() < deadline) {
        var t = findTarget(port, "wildberries.ru", null);
        if (t != null) {
            target = t;
            break;
        }
        if (system.gettickcount() - lastLog > 15000) {
            lastLog = system.gettickcount();
            print("Ожидаю открытия вкладки Wildberries...");
        }
        system.sleep(2);
    }
    if (target == null) {
        error("Вкладка wildberries не открылась");
        system.exit(2);
    }

    var page = attachToPage(target);
    if (page == null) {
        error("Не подключились к вкладке");
        system.exit(3);
    }
    var probe = page.evaluate("1+1");
    var perr1 = coalesce(page.lastError, "нет");
    print("Проверка вычисления 1+1: результат=\(str.toString(probe)), последняя ошибка=\(perr1)");
    var probe2 = page.call("Runtime.evaluate", #{"expression": "1+1"});
    var perr2 = coalesce(page.lastError, "нет");
    print("Проверка Runtime.evaluate без returnByValue: результат=\(str.toString(probe2)), последняя ошибка=\(perr2)");
    var u0 = page.evaluate("document.location.href");
    var perr3 = coalesce(page.lastError, "нет");
    print("Адрес страницы до перехода=\(str.toString(u0)), последняя ошибка=\(perr3)");
    waitPageComplete(page, 30);

    // Ждём фактической загрузки избранного без повторной навигации:
    // антибот-защита может заблокировать частые перезагрузки.

    var tiles = 0;
    var tryNo = 0;
    var lastStatusLog = 0;
    var readyDeadline = system.gettickcount() + 180000;
    while (system.gettickcount() < readyDeadline) {
        if (!pageAlive(page)) {
            page = reconnectWildberries(port, favUrl);
            if (page == null) {
                system.sleep(3);
                continue;
            }
        }
        tiles = wbFavCount(page);
        if (tiles > 0) break;
        tryNo++;
        var ttl = coalesce(pageTitle(page), "?");
        if (system.gettickcount() - lastStatusLog >= 5000) {
            lastStatusLog = system.gettickcount();
            print("Ожидание карточек, попытка \(str.toString(tryNo)): карточек=\(str.toString(tiles)), заголовок=[\(ttl)]");
            if (isWbChallengeTitle(ttl))
                print("Завершите проверку или вход в открытом окне браузера; страница не перезагружается.");
        }
        system.sleep(2);
    }

    var url = currentPageLowerUrl(page);
    var title = coalesce(pageTitle(page), "?");
    print("Адрес страницы: " + url);
    print("Заголовок страницы: " + title);
    tiles = wbFavCount(page);
    print("Карточек в избранном: \(str.toString(tiles))");

    var logged = false;
    if (tiles > 0) logged = true;
    var loginPage = false;
    if (str.pos(str.lower(url), "/login") >= 0) loginPage = true;

    if (logged) {
        print("Сессия активна, страница избранного загружена — сохраняю куки.");
        file.mkdirrecursive("private_data/wildberries");
        saveCookiesToFile(page, "private_data/wildberries/wildberries_cookies.json");
        print("Готово. Можно запустить сканирование: bin\qodeqt.exe wildberries_scan.prg");
    } else {
        print("Куки не сохранены: страница избранного не загрузилась (карточек=\(str.toString(tiles)), открыта страница входа=\(str.toString(loginPage))).");
        print("Возможно, сработала проверка антибота. Для входа запустите bin\qodeqt.exe wildberries_auth.prg.");
    }
    closeConnSafely(page);
    print("Браузер оставлен открытым.");
}

function errText(e) {
    if (e != null) {
        if (e.istuple()) {
            if (e.has("message")) return e.message;
        }
    }
    return str.toString(e);
}

try {
    main();
} catch (e) {
    error("Ошибка: " + errText(e));
    system.exit(1);
}
return 0;
