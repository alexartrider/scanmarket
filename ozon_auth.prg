// Шаг 1. Авторизация: открывает браузер с профилем проекта.
// Пользователь входит на Ozon, после чего скрипт сохраняет куки в private_data/ozon/ozon_cookies.json.
// Запуск из корня проекта: bin\qodeqt.exe ozon_auth.prg
// Куки сохраняются только если найдены товары именно в блоке избранного.
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
        system.exit(2);
    }

    if (!showTargetWindow(target))
        print("Не удалось автоматически вывести окно Ozon на передний план. Проверьте окно браузера на панели задач.");

    var page = attachToPage(target);
    if (page == null) {
        error("Не удалось подключиться к вкладке через DevTools.");
        closeBrowser(port);
        system.exit(3);
    }

    // Дожидаемся начальной загрузки, после чего оставляем страницу пользователю
    // для ручной проверки и входа. Во время ожидания её нельзя перезагружать.
    waitPageComplete(page, 30);

    var readyDeadline = system.gettickcount() + waitLoginSeconds * 1000;
    var favoriteState = -1;
    var lastStatusLog = 0;
    var lastTitle = "";
    while (system.gettickcount() < readyDeadline) {
        if (!pageAlive(page)) {
            print("Соединение CDP потеряно — ищу уже открытую вкладку Ozon...");
            var currentTarget = findOzonTarget(port);
            if (currentTarget != null)
                page = attachToPage(currentTarget);
            if (page == null) {
                system.sleep(2);
                continue;
            }
        }
        favoriteState = favAuthState(page);
        var ttl = coalesce(pageTitle(page), "");
        if (favoriteState > 0 and !isChallengeTitle(ttl)) break;

        if (ttl != lastTitle) {
            lastTitle = ttl;
            if (isChallengeTitle(ttl)) {
                print("Открыта проверочная страница Ozon. Пройдите её в браузере; страницу не перезагружаю.");
            }
        }

        if (system.gettickcount() - lastStatusLog >= 5000) {
            lastStatusLog = system.gettickcount();
            var statusText = "Ожидание входа/избранного: товаров=" + str.toString(favoriteState);
            if (favoriteState == 0)
                statusText = statusText + " (избранное пусто или показаны только рекомендации)";
            print(
                statusText + ", заголовок=[" + ttl + "]"
            );
        }

        system.sleep(1);
    }

    if (favoriteState <= 0 or isChallengeTitle(coalesce(pageTitle(page), ""))) {
        var dl = dumpPageHtml(page, "private_data/ozon/ozon_auth_dump.html", 40000);
        error(
            "Не удалось подтвердить вход в аккаунт Ozon или найти товары в избранном " +
            "(заголовок: [" + coalesce(pageTitle(page), "") +
            "], состояние: " + str.toString(favoriteState) +
            ", размер дампа: " + str.toString(dl) +
            " символов). Куки не сохранены; браузер оставлен открытым."
        );
        closeConnSafely(page);
        system.exit(4);
    }

    print("Страница избранного подтверждена: товаров=\(str.toString(favoriteState))");
    var saved = saveCookiesToFile(page, "private_data/ozon/ozon_cookies.json");
    if (saved == 1) print("Куки сохранены.");
    else print("Не удалось сохранить куки. Проверьте private_data/ozon/ozon_cookies.json.");
    var check = restoreCookiesFromFile(page, "private_data/ozon/ozon_cookies.json");
    print("Проверка: восстановлено кук из файла — \(str.toString(check))");
    system.notify.show("ScanMarket", "Авторизация Ozon сохранена; товаров в избранном: \(str.toString(favoriteState))");
    closeConnSafely(page);
    print("Закрываю браузер после сохранения авторизации и профиля...");
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
