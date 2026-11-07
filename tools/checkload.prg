// Проверка синтаксиса и загрузки модулей: проверяет доступность экспортированных функций.
// Браузер не запускается.
// Запуск из корня проекта: bin\qodeqt.exe tools\checkload.prg.
var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/dbstore.prg");
loadModule("lib/ozon.prg");
loadModule("lib/wildberries.prg");

var cfg = loadConfig("");
print("config browser.proxy = [" + str.toString(cfgGet(cfg, "browser.proxy", "")) + "]");
print("config wildberries.favoritesUrl = [" + str.toString(cfgGet(cfg, "wildberries.favoritesUrl", "")) + "]");

print("currentPageLowerUrl(null)=" + str.toString(currentPageLowerUrl(null)));
print("pageAlive(null)=" + str.toString(pageAlive(null)));
closeConnSafely(null);
print("closeConnSafely(null)=ok");
print("refreshFavoritesForce(null)= " + str.toString(refreshFavoritesForce(null, 1, "x")));
print("refreshWildberriesForce(null)= " + str.toString(refreshWildberriesForce(null, 1, "x")));
print("isChallengeTitle(chl)=" + str.toString(isChallengeTitle("Похоже, нет_connections")));
print("isWbChallengeTitle(chl)=" + str.toString(isWbChallengeTitle("Что-то не так...")));
print("favCount(null)=" + str.toString(favCount(null)));
print("wbFavCount(null)=" + str.toString(wbFavCount(null)));
print("dumpPageHtml(null)=" + str.toString(dumpPageHtml(null, "x", 1)));

storeConnect(cfgGet(cfg, "db.path", "private_data/ozon/ozon.sqlite"));
markStaleRuns();
print("markStaleRuns ok");
print("=== check done ===");
return 0;
