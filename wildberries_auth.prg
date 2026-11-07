// Шаг 1. Авторизация Wildberries: открывает браузер с профилем проекта.
// Пользователь входит на Wildberries, после чего скрипт сохраняет куки
// в private_data/wildberries/wildberries_cookies.json.
// Запуск из корня проекта: bin\qodeqt.exe wildberries_auth.prg
// Куки сохраняются только если страница избранного действительно загрузилась
// (карточек > 0).
// loadModule регистрирует экспортированные функции модулей глобально,
// поэтому loadConfig, cdpSetup и другие функции вызываются напрямую.

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/wildberries.prg");

var cfg = loadConfig("");

function main() {
    var favUrl = cfgGet(cfg, "wildberries.favoritesUrl", "https://www.wildberries.ru/lk/favorites");
    var port = cfgGet(cfg, "browser.debugPort", 9222);
    var profile = cfgGet(cfg, "browser.profileDir", "private_data/browser_profile");
    var waitLoginSeconds = cfgGet(cfg, "wildberries.waitLoginSeconds", 300);

    cdpSetup(port, profile, cfgGet(cfg, "browser.execPath", ""));

    print("=== ScanMarket: авторизация Wildberries ===");
    print("Профиль браузера: " + profile);
    file.mkdirrecursive("private_data/wildberries");
    stopExisting();

    var proc = openBrowser(false, favUrl, cfgGet(cfg, "browser.proxy", ""));
    if (!waitForDevTools(port, 60)) {
        error("DevTools не запустились за 60 секунд. Проверьте browser.execPath в config.json.");
        system.exit(1);
    }

    print("Войдите на Wildberries в открывшемся браузере. Ожидание до \(str.toString(waitLoginSeconds)) сек...");
    var deadline = system.gettickcount() + waitLoginSeconds * 1000;
    var target = null;
    var lastLog = system.gettickcount();
    while (system.gettickcount() < deadline) {
        var t = findWildberriesTarget(port);
        if (t != null) {
            target = t;
            break;
        }
        if (system.gettickcount() - lastLog > 10000) {
            lastLog = system.gettickcount();
            print("Ожидание авторизации: вкладка Wildberries не найдена.");
        }
        system.sleep(1);
    }
    if (target == null) {
        error("Страница Wildberries не открылась за \(str.toString(waitLoginSeconds)) секунд. Попробуйте ещё раз.");
        system.exit(2);
    }

    if (!showTargetWindow(target))
        print("Не удалось автоматически вывести окно Wildberries на передний план. Проверьте окно браузера на панели задач.");

    var page = attachToPage(target);
    if (page == null) {
        error("Не удалось подключиться к вкладке через DevTools.");
        closeBrowser(port);
        system.exit(3);
    }

    // Ждём фактической загрузки избранного, не перезагружая страницу.
    // Повторная навигация может вызвать антибот-защиту и заблокировать вход.
    var readyDeadline = system.gettickcount() + waitLoginSeconds * 1000;
    var tiles = -1;
    var lastStatusLog = 0;
    while (system.gettickcount() < readyDeadline) {
        if (!pageAlive(page)) {
            print("Соединение CDP потеряно — подключаюсь к вкладке повторно...");
            var existingTarget = findWildberriesTarget(port);
            if (existingTarget != null)
                page = attachToPage(existingTarget);
            if (page == null) {
                system.sleep(2);
                continue;
            }
        }
        tiles = wbFavCount(page);
        var ttl = coalesce(pageTitle(page), "");
        if (tiles > 0) break;
        if (system.gettickcount() - lastStatusLog >= 5000) {
            lastStatusLog = system.gettickcount();
            print("Ожидаю избранное: карточек=\(str.toString(tiles)), заголовок=[\(ttl)]");
            if (isWbChallengeTitle(ttl))
                print("  Завершите проверку или вход в открытом окне браузера; страница не перезагружается.");
        }
        system.sleep(2);
    }

    if (tiles <= 0) {
        var dl = dumpPageHtml(page, "private_data/wildberries/wildberries_auth_dump.html", 40000);
        error("Карточки избранного не появились за отведённое время (размер дампа: \(str.toString(dl)) символов). Куки не сохранены. Браузер оставлен открытым: завершите вход вручную и запустите wildberries_check_session.prg.");
        closeConnSafely(page);
        system.exit(4);
    }

    print("Страница избранного загружена: карточек=\(str.toString(tiles))");
    file.mkdirrecursive("private_data/wildberries");
    var saved = saveCookiesToFile(page, "private_data/wildberries/wildberries_cookies.json");
    if (saved == 1) print("Куки сохранены.");
    else print("Не удалось сохранить куки. Проверьте private_data/wildberries/wildberries_cookies.json.");
    var check = restoreCookiesFromFile(page, "private_data/wildberries/wildberries_cookies.json", ".wildberries.ru");
    print("Проверка: восстановлено кук из файла — \(str.toString(check))");
    system.notify.show("ScanMarket", "Авторизация Wildberries сохранена; карточек избранного: \(str.toString(tiles))");
    closeConnSafely(page);
    print("Закрываю браузер после сохранения авторизации и профиля...");
    closeBrowser(port);
    print("Готово. Теперь можно запустить сканирование: bin\qodeqt.exe wildberries_scan.prg");
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
