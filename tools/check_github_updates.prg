// Фоновая проверка GitHub для кнопки GUI.
// Сохраняет результат в файл, указанный вторым аргументом; SQLite не открывает.

var updateResultPath = "";
var commandLine = system.getcommandline();
if (commandLine.args.size() > 1)
    updateResultPath = str.toString(commandLine.args[1]);

var updateCachePath = file.join(file.tempdir(), "scanmarket_github_update_cache.json");
var updateCache = #[];

function cacheIndexForPath(cache, path)
{
    for (var i = 0; i < cache.size(); i++)
    {
        if (cache[i].get("path") == path)
            return i;
    }

    return -1;
}

function saveUpdateCache(cache)
{
    file.write(updateCachePath, json.stringify(cache), file.ENC_UTF8_NO_BOM);
}

function fail(message)
{
    var resultText = json.stringify(#{"ok": false, "error": message});
    if (updateResultPath != "")
        file.write(updateResultPath, resultText, file.ENC_UTF8_NO_BOM);
    else
        print(resultText);

    system.exit(1);
}

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    fail("Не удалось перейти в каталог проекта: " + projectDir);

if (!loadPlugin(file.join(file.programpath(), "plugins", "http.dll")))
    fail("Не удалось загрузить HTTP-плагин Qode");

if (!loadPlugin(file.join(file.programpath(), "plugins", "crypto.dll")))
    fail("Не удалось загрузить Crypto-плагин Qode");

if (file.isfile(updateCachePath))
{
    try
    {
        var cached = json.parse(str.toString(file.read(updateCachePath)));
        if (cached != null and typeName(cached) == "array")
            updateCache = cached;
    }
    catch (e)
    {
        updateCache = #[];
    }
}

var http = HttpClient();
http.setTimeout(15000);
http.setUserAgent("ScanMarket-update-check");
http.setHeader("Accept", "application/vnd.github+json");
var githubToken = str.toString(coalesce(file.getenv("GITHUB_TOKEN"), ""));
if (githubToken != "")
    http.setBearerAuth(githubToken);

var cryptoService = Crypto();
var checked = 0;
var changed = #[];
var pendingDirectories = #[""];
var usedRateLimitCache = false;

while (!pendingDirectories.empty())
{
    var directory = str.toString(pendingDirectories.pop());
    var contentsUrl = "https://api.github.com/repos/alexartrider/scanmarket/contents/";
    var cachedIndex = cacheIndexForPath(updateCache, directory);
    var entries = null;
    var responseBody = "";
    var responseEtag = "";

    if (directory != "")
        contentsUrl += directory;

    http.clearHeaders();
    http.setHeader("Accept", "application/vnd.github+json");
    http.setUserAgent("ScanMarket-update-check");
    if (githubToken != "")
        http.setBearerAuth(githubToken);
    if (cachedIndex >= 0)
    {
        var cachedEtag = str.toString(coalesce(updateCache[cachedIndex].get("etag"), ""));
        if (cachedEtag != "")
            http.setHeader("If-None-Match", cachedEtag);
    }

    if (!http.get(contentsUrl))
        fail("Не удалось получить список файлов '" + directory + "': "
            + str.toString(http.lastError()));

    var responseStatus = http.status();
    if (responseStatus == 304)
    {
        if (cachedIndex < 0)
            fail("GitHub вернул HTTP 304 без сохранённого ответа для '" + directory + "'");

        var cachedBody = str.toString(coalesce(updateCache[cachedIndex].get("body"), ""));
        if (cachedBody == "")
            fail("Кэшированный ответ GitHub пуст для '" + directory + "'");

        try
        {
            entries = json.parse(cachedBody);
        }
        catch (e)
        {
            fail("Не удалось разобрать кэш GitHub для '" + directory + "'");
        }
    }
    else if (responseStatus == 200)
    {
        responseBody = http.getResponse();
        try
        {
            entries = json.parse(responseBody);
        }
        catch (e)
        {
            fail("Не удалось разобрать GitHub JSON для '" + directory + "': "
                + str.toString(e));
        }

        responseEtag = str.toString(coalesce(http.getHeader("ETag"), ""));
        if (cachedIndex < 0)
        {
            updateCache.push(#{
                "path": directory,
                "etag": responseEtag,
                "body": responseBody
            });
        }
        else
        {
            updateCache[cachedIndex] = #{
                "path": directory,
                "etag": responseEtag,
                "body": responseBody
            };
        }

        saveUpdateCache(updateCache);
    }
    else if (responseStatus == 403 or responseStatus == 402 or responseStatus == 429)
    {
        if (cachedIndex >= 0)
        {
            var cachedBody = str.toString(coalesce(updateCache[cachedIndex].get("body"), ""));
            if (cachedBody != "")
            {
                try
                {
                    entries = json.parse(cachedBody);
                    usedRateLimitCache = true;
                }
                catch (e)
                {
                    entries = null;
                }
            }
        }

        if (entries == null)
        {
            var rateLimitReset = str.toString(
                coalesce(http.getHeader("X-RateLimit-Reset"), "")
            );
            var resetMessage = rateLimitReset == ""
                ? ""
                : " Время сброса лимита Unix: " + rateLimitReset + ".";
            fail("GitHub ограничил частоту API-запросов (HTTP "
                + str.toString(responseStatus) + "). Повторите позже или настройте "
                + "переменную окружения GITHUB_TOKEN для увеличения лимита."
                + resetMessage);
        }
    }
    else
    {
        fail("GitHub вернул HTTP " + str.toString(http.status())
            + " для '" + directory + "': " + http.statusText());
    }

    if (entries == null or typeName(entries) != "array")
        fail("GitHub вернул не массив файлов для '" + directory + "'");

    for (var item : entries)
    {
        var path = str.toString(coalesce(item.get("path"), ""));
        var itemType = str.toString(coalesce(item.get("type"), ""));

        if (itemType == "dir")
        {
            if (path == "private_data" or str.startswith(path, "private_data/")
                or path == "docs" or str.startswith(path, "docs/")
                or path == "test" or str.startswith(path, "test/")
                or path == "bin" or str.startswith(path, "bin/")
                or path == "Redist" or str.startswith(path, "Redist/"))
                continue;

            pendingDirectories.push(path);
            continue;
        }

        if (itemType != "file")
            continue;

        var extension = str.lower(file.extension(path));
        if (extension != ".prg" and extension != ".json")
            continue;

        if (path == "config.json" or path == "config.example.json")
            continue;

        checked++;
        var localPath = file.join(projectDir, path);
        if (!file.isfile(localPath))
        {
            changed.push("новый: " + path);
            continue;
        }

        var localBytes = file.readbytes(localPath);
        if (localBytes == null)
        {
            changed.push("не удалось прочитать: " + path);
            continue;
        }

        // Удаляем CR из CRLF и используем обновлённый индексный ByteArray iterator.
        var normalizedBytes = ByteArray();
        for (var [byteIndex, byteValue] : localBytes)
        {
            if (byteValue == 13 and byteIndex + 1 < localBytes.size()
                and localBytes[byteIndex + 1] == 10)
                continue;

            normalizedBytes.push(byteValue);
        }

        var blob = ByteArray.fromString(
            "blob " + str.toString(normalizedBytes.size()),
            ByteArray.encode_utf8
        );
        blob.push(0);

        for (var contentByte : normalizedBytes)
            blob.push(contentByte);

        var localSha = str.lower(cryptoService.sha1(blob));
        var remoteSha = str.lower(str.toString(coalesce(item.get("sha"), "")));

        if (remoteSha == "")
        {
            changed.push("нет SHA в ответе GitHub: " + path);
            continue;
        }

        if (localSha != remoteSha)
            changed.push("обновлён: " + path);
    }
}

var warning = usedRateLimitCache
    ? "GitHub ограничил API; часть списков взята из локального кэша и может быть устаревшей"
    : "";
var resultText = json.stringify(#{
    "ok": true,
    "checked": checked,
    "changed": changed,
    "warning": warning
});

if (updateResultPath != "")
{
    if (!file.write(updateResultPath, resultText, file.ENC_UTF8_NO_BOM))
        fail("Не удалось записать результат проверки: " + updateResultPath);
}
else
{
    print(resultText);
}

return 0;
