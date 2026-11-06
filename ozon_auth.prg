// Шаг 1. Авторизация: открывает браузер с профилем проекта.
// Пользователь входит на Ozon, после чего скрипт сохраняет куки в private_data/ozon/ozon_cookies.json.
// Запуск из корня проекта: bin\qodeqt.exe ozon_auth.prg
// Куки сохраняются только если страница избранного действительно загрузилась (карточек > 0).
// loadModule регистрирует экспортированные функции модулей глобально,
// поэтому loadConfig, cdpSetup и другие функции вызываются напрямую.

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/ozon.prg");

var cfg = loadConfig("");

function main() {
    var favUrl = cfgGet(cfg, "ozon.favoritesUrl", "https://www.ozon.ru/my/favorites");
    var port = cfgGet(cfg, "browser.debugPort", 9222);
    var profile = cfgGet(cfg, "browser.profileDir", "private_data/browser_profile");
    var waitLoginSeconds = cfgGet(cfg, "ozon.waitLoginSeconds", 300);

    cdpSetup(port, profile, cfgGet(cfg, "browser.execPath", ""));

    print("=== ScanMarket: авторизация Ozon ===");
    print("Профиль браузера: " + profile);
    stopExisting();

    var proc = openBrowser(false, favUrl, cfgGet(cfg, "browser.proxy", ""));
    if (!waitForDevTools(port, 60)) {
        error("DevTools не запустились за 60 секунд. Проверьте browser.execPath в config.json.");
        system.exit(1);
    }

    print("Войдите на Ozon в открывшемся браузере. Ожидание до \(str.toString(waitLoginSeconds)) сек...");
    var deadline = system.gettickcount() + waitLoginSeconds * 1000;
    var target = null;
    var lastLog = system.gettickcount();
    while (system.gettickcount() < deadline) {
        var t = findOzonTarget(port);
        if (t != null) {
            target = t;
            break;
        }
        if (system.gettickcount() - lastLog > 10000) {
            lastLog = system.gettickcount();
            print("Ожидание авторизации: вкладка Ozon не найдена.");
        }
        system.sleep(1);
    }
    if (target == null) {
        error("Страница Ozon не открылась за \(str.toString(waitLoginSeconds)) секунд. Попробуйте ещё раз.");
        closeBrowser(port);
        system.exit(2);
    }

    var page = attachToPage(target);
    if (page == null) {
        error("Не удалось подключиться к вкладке через DevTools.");
        closeBrowser(port);
        system.exit(3);
    }

    // Ждём фактической загрузки страницы избранного (карточек > 0): проверка антибота
    // может показать страницу-заглушку вместо избранного.
    var readyDeadline = system.gettickcount() + waitLoginSeconds * 1000;
    var tiles = -1;
    while (system.gettickcount() < readyDeadline) {
        if (!pageAlive(page)) {
            print("Соединение CDP потеряно — подключаюсь к вкладке повторно...");
            page = reconnectFavorites(port, favUrl);
            if (page == null) {
                system.sleep(2);
                continue;
            }
        }
        waitPageComplete(page, 20);
        tiles = favCount(page);
        var ttl = coalesce(pageTitle(page), "");
        if (tiles > 0) break;
        print("Ожидание страницы избранного: карточек=\(str.toString(tiles)), заголовок=[\(ttl)]");
        if (isChallengeTitle(ttl)) {
            print("  Открыта проверочная страница Ozon — ожидаю 8 секунд...");
            system.sleep(8);
            var c2 = favCount(page);
            if (c2 > 0) {
                tiles = c2;
                break;
            }
        }
        page = refreshFavoritesForce(page, port, favUrl);
    }

    if (tiles <= 0) {
        var dl = dumpPageHtml(page, "private_data/ozon/ozon_auth_dump.html", 40000);
        error("Страница избранного не загрузилась (карточек: 0, размер дампа: \(str.toString(dl)) символов). Куки не сохранены; войдите в аккаунт и повторите попытку.");
        closeConnSafely(page);
        closeBrowser(port);
        system.exit(4);
    }

    print("Страница избранного загружена: карточек=\(str.toString(tiles))");
    var saved = saveCookiesToFile(page, "private_data/ozon/ozon_cookies.json");
    if (saved == 1) print("Куки сохранены.");
    else print("Не удалось сохранить куки. Проверьте private_data/ozon/ozon_cookies.json.");
    var check = restoreCookiesFromFile(page, "private_data/ozon/ozon_cookies.json");
    print("Проверка: восстановлено кук из файла — \(str.toString(check))");
    system.notify.show("ScanMarket", "Авторизация Ozon сохранена; карточек избранного: \(str.toString(tiles))");
    closeConnSafely(page);
    print("Корректно закрываю браузер, чтобы сохранить профиль на диск...");
    closeBrowser(port);
    print("Готово. Теперь можно запустить сканирование: bin\qodeqt.exe ozon_scan.prg");
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
