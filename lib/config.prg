// config.prg — загрузка и создание config.json
// Обращение: loadModule("lib/config.prg"); затем loadConfig(""), cfgGet(...)

var configFile = "config.json";

// Читает файл в любой из возможных кодировок
function readTextAny(path) export {
    var encVariants = #[null, file.ENC_UTF8_BOM, file.ENC_UTF8_NO_BOM, file.ENC_CP1251];
    for (var enc : encVariants) {
        var text = null;
        try {
            if (enc == null) text = file.read(path);
            else text = file.read(path, enc);
        } catch (e) {
            continue;
        }
        if (text != null and text != "") return text;
    }
    return null;
}

// Рекурсивное слияние: значения из src затирают dst
function deepMerge(dst, src) export {
    var keys = src.keys();
    for (var k : keys) {
        var sv = src.get(k);
        var goDeep = (sv != null and sv.istuple());
        if (goDeep) goDeep = dst.has(k);
        if (goDeep) goDeep = dst.get(k).istuple();
        if (goDeep) {
            deepMerge(dst.get(k), sv);
        } else {
            dst.set(k, sv);
        }
    }
    return dst;
}

// Загрузка настроек; если файла нет — создаёт с значениями по умолчанию
function loadConfig(path) export {
    var emptyPath = (path == null);
    if (!emptyPath) emptyPath = (path == "");
    if (!emptyPath) configFile = path;
    var dflt = #{
        "browser": #{
            "headless": false,         // false — с окном: Ozon антиботом блокирует headless
            "execPath": "",            // свой путь к msedge.exe/chrome.exe, если автоопределение не сработало
            "debugPort": 9222,         // порт DevTools
            "profileDir": "private_data/browser_profile" // папка профиля браузера
        },
        "ozon": #{
            "favoritesUrl": "https://www.ozon.ru/my/favorites",
            "waitLoginSeconds": 300,   // сколько ждать входа/страницы избранного
            "pageWaitSeconds": 25,     // сколько ждать полной загрузки страницы
            "maxScrollSteps": 40,      // максимум шагов прокрутки избранного
            "stopTrailing": 5,         // остановить прокрутку после этого числа шагов без новых избранных карточек
            "chunk": 12                // размер порции карточек при запросе через CDP
        },
        "wildberries": #{
            "favoritesUrl": "https://www.wildberries.ru/lk/favorites",
            "dbPath": "private_data/wildberries/wildberries.sqlite",
            "waitLoginSeconds": 300,   // сколько ждать входа/страницы избранного
            "pageWaitSeconds": 25,     // сколько ждать полной загрузки страницы
            "maxScrollSteps": 40,      // максимум шагов прокрутки избранного
            "stopTrailing": 5,         // остановить прокрутку после этого числа шагов без новых избранных карточек
            "chunk": 12                // размер порции карточек при запросе через CDP
        },
        "yandexmarket": #{
            "favoritesUrl": "https://market.yandex.ru/my/wishlist",
            "dbPath": "private_data/yandexmarket/yandexmarket.sqlite",
            "waitLoginSeconds": 300,   // сколько ждать входа/страницы избранного
            "pageWaitSeconds": 25,     // сколько ждать полной загрузки страницы
            "maxScrollSteps": 40,      // максимум шагов прокрутки избранного
            "stopTrailing": 5,         // остановить прокрутку после этого числа шагов без новых избранных карточек
            "chunk": 12                // размер порции карточек при запросе через CDP
        },
        "db": #{
            "path": "private_data/ozon/ozon.sqlite"
        },
        "cronWb": #{
            "taskName": "ScanMarketWildberries", // имя task планировщика Windows
            "mode": "daily",              // daily | hourly
            "start": "06:00",             // время для daily (/sc daily /st)
            "everyHours": 6,              // шаг для hourly (/sc hourly /mo)
            "exe": "bin/qodeqt.exe",          // исполнитель для task
            "script": "wildberries_scan.prg", // скрипт
            "bat": "scan_wildberries.bat"     // BAT-файл запуска
        },
        "cron": #{
            "taskName": "ScanMarketOzon", // имя task планировщика Windows
            "mode": "daily",              // daily | hourly
            "start": "06:00",             // время для daily (/sc daily /st)
            "everyHours": 6,              // шаг для hourly (/sc hourly /mo)
            "exe": "bin/qodeqt.exe",          // исполнитель для task
            "script": "ozon_scan.prg",    // скрипт
            "bat": "scan_ozon.bat"        // BAT-файл запуска (переход в каталог проекта и запуск скрипта)
        },
        "cronYm": #{
            "taskName": "ScanMarketYandexMarket", // имя task планировщика Windows
            "mode": "daily",              // daily | hourly
            "start": "06:00",             // время для daily (/sc daily /st)
            "everyHours": 6,              // шаг для hourly (/sc hourly /mo)
            "exe": "bin/qodeqt.exe",          // исполнитель для task
            "script": "yandexmarket_scan.prg", // скрипт
            "bat": "scan_yandexmarket.bat"     // BAT-файл запуска (переход в каталог проекта и запуск скрипта)
        }
    };
    if (!file.exists(configFile)) {
        file.write(configFile, json.stringify(dflt, true), file.ENC_UTF8_BOM);
        print("Создан файл настроек: \(file.absolute(configFile))");
        return dflt;
    }
    var text = readTextAny(configFile);
    var noText = (text == null);
    var emptyText = false;
    if (text != null) emptyText = (text == "");
    if (noText or emptyText) {
        error("Не удалось прочитать \(configFile) — использую значения по умолчанию");
        return dflt;
    }
    var loaded = null;
    try { loaded = json.parse(text); } catch (e) { loaded = null; }
    var ok = loaded != null;
    if (ok) {
        return deepMerge(dflt, loaded);
    }
    error("Файл \(configFile) повреждён — использую значения по умолчанию");
    return dflt;
}

// Чтение значения по пути "ozon.favoritesUrl" со значением по умолчанию
function cfgGet(cfg, path, dv) export {
    var node = cfg;
    var parts = str.split(path, ".");
    for (var p : parts) {
        if (node == null) return dv;
        if (!node.istuple()) return dv;
        node = node.get(p);
    }
    if (node == null) return dv;
    return node;
}
