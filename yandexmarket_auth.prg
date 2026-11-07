// Шаг 1. Авторизация Яндекс Маркета: открывает браузер с профилем проекта.
// Пользователь входит на Яндекс, после чего скрипт сохраняет куки
// в private_data/yandexmarket/yandexmarket_cookies.json.
// Запуск из корня проекта: bin\qodeqt.exe yandexmarket_auth.prg
// Куки сохраняются только если вишлист действительно загрузился: в избранном
// есть товары с активным сердечком либо открыт пустой вишлист без кнопки «Войти».
// loadModule регистрирует экспортированные функции модулей глобально,
// поэтому loadConfig, cdpSetup и другие функции вызываются напрямую.

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/yandexmarket.prg");

var cfg = loadConfig("");

function main() {
    var favUrl = cfgGet(cfg, "yandexmarket.favoritesUrl", "https://market.yandex.ru/my/wishlist");
    var port = cfgGet(cfg, "browser.debugPort", 9222);
    var profile = cfgGet(cfg, "browser.profileDir", "private_data/browser_profile");
    var waitLoginSeconds = cfgGet(cfg, "yandexmarket.waitLoginSeconds", 300);

    cdpSetup(port, profile, cfgGet(cfg, "browser.execPath", ""));

    print("=== ScanMarket: авторизация Яндекс Маркета ===");
    print("Профиль браузера: " + profile);
    file.mkdirrecursive("private_data/yandexmarket");
    stopExisting();

    var proc = openBrowser(false, favUrl, cfgGet(cfg, "browser.proxy", ""));
    if (!waitForDevTools(port, 60)) {
        error("DevTools не запустились за 60 секунд. Проверьте browser.execPath в config.json.");
        system.exit(1);
    }

    print("Войдите на Яндекс Маркет в открывшемся браузере. Ожидание до \(str.toString(waitLoginSeconds)) сек...");
    var deadline = system.gettickcount() + waitLoginSeconds * 1000;
    var target = null;
    var lastLog = system.gettickcount();
    while (system.gettickcount() < deadline) {
        var t = findYandexMarketTarget(port);
        if (t != null) {
            target = t;
            break;
        }
        if (system.gettickcount() - lastLog > 10000) {
            lastLog = system.gettickcount();
            print("Ожидание авторизации: вкладка Яндекс Маркета не найдена.");
        }
        system.sleep(1);
    }
    if (target == null) {
        error("Страница Яндекс Маркета не открылась за \(str.toString(waitLoginSeconds)) секунд. Попробуйте ещё раз.");
        system.exit(2);
    }

    showTargetWindow(target);

    var page = attachToPage(target);
    if (page == null) {
        error("Не удалось подключиться к вкладке через DevTools.");
        closeBrowser(port);
        system.exit(3);
    }

    // Ждём фактической загрузки вишлиста, не перезагружая страницу.
    // Повторная навигация может вызвать антибот-защиту и заблокировать вход.
    // Признак входа: есть активные сердечки (товары в избранном) либо
    // открыт пустой вишлист без кнопки «Войти».
    var readyDeadline = system.gettickcount() + waitLoginSeconds * 1000;
    var active = -1;
    var empty = 0;
    var guest = -1;
    var lastStatusLog = 0;
    while (system.gettickcount() < readyDeadline) {
        if (!pageAlive(page)) {
            print("Соединение CDP потеряно — подключаюсь к вкладке повторно...");
            var existingTarget = findYandexMarketTarget(port);
            if (existingTarget != null)
                page = attachToPage(existingTarget);
            if (page == null) {
                system.sleep(2);
                continue;
            }
        }
        active = ymFavActiveCount(page);
        empty = ymEmptyState(page);
        guest = ymGuestState(page);
        if (active > 0) break;
        if (empty == 1 and guest == 0) break;
        if (system.gettickcount() - lastStatusLog >= 5000) {
            lastStatusLog = system.gettickcount();
            var ttl = coalesce(pageTitle(page), "");
            print("Ожидаю вишлист: сердечек=\(str.toString(active)), пусто=\(str.toString(empty)), гость=\(str.toString(guest)), заголовок=[\(ttl)]");
            if (isYmChallengeTitle(ttl))
                print("  Завершите проверку или вход в открытом окне браузера; страница не перезагружается.");
        }
        system.sleep(2);
    }

    if (active <= 0 and !(empty == 1 and guest == 0)) {
        var dl = dumpPageHtml(page, "private_data/yandexmarket/yandexmarket_auth_dump.html", 40000);
        error("Вишлист не загрузился (сердечек: \(str.toString(active)), размер дампа: \(str.toString(dl)) символов). Куки не сохранены. Браузер оставлен открытым: завершите вход вручную и запустите yandexmarket_check_session.prg.");
        closeConnSafely(page);
        system.exit(4);
    }

    if (active > 0)
        print("Страница вишлиста загружена: товаров в избранном=\(str.toString(active))");
    else
        print("Страница вишлиста загружена: избранное пустое.");
    saveCookiesSafely(page);
    system.notify.show("ScanMarket", "Авторизация Яндекс Маркета сохранена; товаров в избранном: \(str.toString(active))");
    closeConnSafely(page);
    print("Закрываю браузер после сохранения авторизации и профиля...");
    closeBrowser(port);
    print("Готово. Теперь можно запустить сканирование: bin\qodeqt.exe yandexmarket_scan.prg");
}

function saveCookiesSafely(page) {
    file.mkdirrecursive("private_data/yandexmarket");
    var saved = saveCookiesToFile(page, "private_data/yandexmarket/yandexmarket_cookies.json");
    if (saved == 1) print("Куки сохранены.");
    else print("Не удалось сохранить куки. Проверьте private_data/yandexmarket/yandexmarket_cookies.json.");
    var check = restoreCookiesFromFile(page, "private_data/yandexmarket/yandexmarket_cookies.json", ".yandex.ru");
    print("Проверка: восстановлено кук из файла — \(str.toString(check))");
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
