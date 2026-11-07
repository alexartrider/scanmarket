// Проверка: открывает профиль в браузере (Yandex/Edge/Chrome),
// доходит до «Избранного» Яндекс Маркета и: если сессия жива — сохраняет куки
// в private_data/yandexmarket/yandexmarket_cookies.json,
// иначе пишет «нужен вход» (запустить yandexmarket_auth.prg).
var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/yandexmarket.prg");

var cfg = loadConfig("");

function main() {
    var port = cfgGet(cfg, "browser.debugPort", 9222);
    var profile = cfgGet(cfg, "browser.profileDir", "private_data/browser_profile");
    var favUrl = cfgGet(cfg, "yandexmarket.favoritesUrl", "https://market.yandex.ru/my/wishlist");

    cdpSetup(port, profile, cfgGet(cfg, "browser.execPath", ""));
    print("Браузер: " + coalesce(findBrowser(), "не найден"));
    var existingYm = findYandexMarketTarget(port);

    if (existingYm == null) {
        var profileProcesses = profileProcCount();
        if (profileProcesses > 0) {
            error("Браузер проекта уже открыт, но вкладка Яндекс Маркета не найдена. " +
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

    // ищем вкладку Яндекс Маркета
    var target = null;
    var deadline = system.gettickcount() + 120000;
    var lastLog = system.gettickcount();
    while (system.gettickcount() < deadline) {
        var t = findYandexMarketTarget(port);
        if (t != null) {
            target = t;
            break;
        }
        if (system.gettickcount() - lastLog > 15000) {
            lastLog = system.gettickcount();
            print("Ожидаю открытия вкладки Яндекс Маркета...");
        }
        system.sleep(2);
    }
    if (target == null) {
        error("Вкладка Яндекс Маркета не открылась");
        system.exit(2);
    }

    showTargetWindow(target);

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

    // Ждём фактической загрузки вишлиста без повторной навигации:
    // антибот-защита может заблокировать частые перезагрузки.
    // Признак входа: активные сердечки либо пустой вишлист без кнопки «Войти».

    var active = -1;
    var empty = 0;
    var guest = -1;
    var tryNo = 0;
    var lastStatusLog = 0;
    var readyDeadline = system.gettickcount() + 180000;
    while (system.gettickcount() < readyDeadline) {
        if (!pageAlive(page)) {
            page = reconnectYandexMarket(port, favUrl);
            if (page == null) {
                system.sleep(3);
                continue;
            }
        }
        active = ymFavActiveCount(page);
        empty = ymEmptyState(page);
        guest = ymGuestState(page);
        if (active > 0) break;
        if (empty == 1 and guest == 0) break;
        tryNo++;
        if (system.gettickcount() - lastStatusLog >= 5000) {
            lastStatusLog = system.gettickcount();
            var ttl = coalesce(pageTitle(page), "?");
            print("Ожидание вишлиста, попытка \(str.toString(tryNo)): сердечек=\(str.toString(active)), гость=\(str.toString(guest)), заголовок=[\(ttl)]");
            if (isYmChallengeTitle(ttl))
                print("Завершите проверку или вход в открытом окне браузера; страница не перезагружается.");
        }
        system.sleep(2);
    }

    var url = currentPageLowerUrl(page);
    var title = coalesce(pageTitle(page), "?");
    print("Адрес страницы: " + url);
    print("Заголовок страницы: " + title);
    active = ymFavActiveCount(page);
    empty = ymEmptyState(page);
    guest = ymGuestState(page);
    print("Товаров в избранном: \(str.toString(active))");

    var logged = false;
    if (active > 0) logged = true;
    if (empty == 1 and guest == 0) logged = true;
    var loginPage = false;
    if (str.pos(str.lower(url), "passport.yandex.ru") >= 0) loginPage = true;

    if (logged) {
        print("Сессия активна, страница вишлиста загружена — сохраняю куки.");
        file.mkdirrecursive("private_data/yandexmarket");
        saveCookiesToFile(page, "private_data/yandexmarket/yandexmarket_cookies.json");
        print("Готово. Можно запустить сканирование: bin\qodeqt.exe yandexmarket_scan.prg");
    } else {
        print("Куки не сохранены: страница вишлиста не загрузилась (товаров=\(str.toString(active)), открыта страница входа=\(str.toString(loginPage))).");
        print("Возможно, сработала проверка антибота. Для входа запустите bin\qodeqt.exe yandexmarket_auth.prg.");
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
