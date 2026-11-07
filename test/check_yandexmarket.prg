// check_yandexmarket.prg — проверка загрузки модулей Яндекс Маркета
// без запуска браузера. Запуск: bin\qodeqt.exe test\check_yandexmarket.prg
// PASS = код возврата 0.

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
projectDir = file.dirname(projectDir);
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/yandexmarket.prg");
loadModule("lib/dbstore.prg");

var cfg = loadConfig("");

var ok = true;

function checkFunction(name) {
    var present = exists(name);
    if (!present) ok = false;
    print("  " + name + ": " + (present ? "найдена" : "ОТСУТСТВУЕТ"));
}

function checkMethod(name, object, method) {
    var present = methodExists(object, method);
    if (!present) ok = false;
    print("  " + name + ": " + (present ? "найден" : "ОТСУТСТВУЕТ"));
}

function checkVal(name, expected, actual) {
    var same = (str.toString(coalesce(actual, "NULL")) == str.toString(expected));
    if (!same) ok = false;
    print("  \(name): " + str.toString(coalesce(actual, "NULL")) +
        (same ? "" : " (ожидалось \(str.toString(expected)))"));
}

print("=== Проверка настроек конфигурации ===");
checkVal("yandexmarket.favoritesUrl", "https://market.yandex.ru/my/wishlist",
    cfgGet(cfg, "yandexmarket.favoritesUrl", ""));
checkVal("yandexmarket.dbPath", "private_data/yandexmarket/yandexmarket.sqlite",
    cfgGet(cfg, "yandexmarket.dbPath", ""));
checkVal("cronYm.taskName", "ScanMarketYandexMarket", cfgGet(cfg, "cronYm.taskName", ""));
checkVal("cronYm.script", "yandexmarket_scan.prg", cfgGet(cfg, "cronYm.script", ""));
checkVal("cronYm.bat", "scan_yandexmarket.bat", cfgGet(cfg, "cronYm.bat", ""));

print("=== Проверка экспортируемых функций lib/yandexmarket.prg ===");
checkFunction("ymFavCount");
checkFunction("ymFavActiveCount");
checkFunction("ymEmptyState");
checkFunction("ymGuestState");
checkFunction("ymFavScroll");
checkFunction("ymFavCollect");
checkFunction("ymCardProduct");
checkFunction("ymFavProducts");
checkFunction("ymScanWasComplete");
checkFunction("ymScanIds");
checkFunction("isYmChallengeTitle");

print("=== Проверка cdp-функций ===");
checkFunction("findYandexMarketTarget");
checkFunction("reconnectYandexMarket");

print("=== Проверка methodExists на строковом модуле ===");
checkMethod("str.rfind", str, "rfind");
var hasRpos = methodExists(str, "rpos");
print("  str.rpos: " + (hasRpos ? "найден" : "не найден в рантайме (известное расхождение со спецификацией)"));

print("=== Проверка нормализации ===");
checkVal("ymFavCount(null)", -1, ymFavCount(null));
checkVal("ymFavActiveCount(null)", -1, ymFavActiveCount(null));
checkVal("ymEmptyState(null)", 0, ymEmptyState(null));
checkVal("ymGuestState(null)", -1, ymGuestState(null));
checkVal("normalizePrice('3 841 ₽')", 3841, normalizePrice("3 841 ₽"));
checkVal("idFromLink('/card/tiski-100/4907020310')", "4907020310",
    idFromLink("https://market.yandex.ru/card/tiski-100/4907020310"));
checkVal("idFromLink('/product/123456')", "123456",
    idFromLink("https://market.yandex.ru/product/123456"));
checkVal("normalizeLink('/card/x/1')", "https://market.yandex.ru/card/x/1",
    normalizeLink("/card/x/1"));

print("=== Проверка source для БД ===");
storeSetSource("yandexmarket");
checkVal("source=yandexmarket", "yandexmarket", source);

if (!ok) {
    error("Проверка не пройдена — смотрите выше.");
    system.exit(1);
}
print("Все проверки пройдены.");
return 0;
