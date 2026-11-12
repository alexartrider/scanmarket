// Независимая проверка GitHub Contents API и Git blob SHA.
// Не открывает GUI, не подключается к SQLite и ничего не записывает в проект.
// Запуск из корня: bin\qodeqt.exe test\check_github_updates.prg

function fail(message)
{
    print("ОШИБКА: " + message);
    system.exit(1);
}

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    fail("Не удалось перейти в каталог проекта: " + projectDir);

if (!loadPlugin(file.join(file.programpath(), "plugins", "http.dll")))
    fail("Не удалось загрузить HTTP-плагин Qode");

if (!loadPlugin(file.join(file.programpath(), "plugins", "crypto.dll")))
    fail("Не удалось загрузить Crypto-плагин Qode");

// Контроль ByteArray iteration: порядок, значения и количество байтов.
var iterationSource = ByteArray();
iterationSource.push(0, 1, 127, 255);

var iterationCopy = ByteArray();
for (var byteValue : iterationSource)
    iterationCopy.push(byteValue);

if (iterationCopy.size() != iterationSource.size())
    fail("for ... : скопировал неверное количество байтов: "
        + str.toString(iterationCopy.size()) + " вместо "
        + str.toString(iterationSource.size()));

for (var i = 0; i < iterationSource.size(); i++)
{
    if (iterationCopy[i] != iterationSource[i])
        fail("for ... : изменил байт с индексом " + str.toString(i));
}

var http = HttpClient();
http.setTimeout(15000);
http.setUserAgent("ScanMarket-update-check-test");
http.setHeader("Accept", "application/vnd.github+json");

var cryptoService = Crypto();
var checked = 0;
var changed = #[];
var pendingDirectories = #[""];
var requestCount = 0;
var testStartedAt = system.gettickcount();

while (!pendingDirectories.empty())
{
    var directory = str.toString(pendingDirectories.pop());
    var contentsUrl = "https://api.github.com/repos/alexartrider/scanmarket/contents/";

    if (directory != "")
        contentsUrl += directory;

    requestCount++;
    var requestStartedAt = system.gettickcount();
    print("GitHub API [" + str.toString(requestCount) + "]: "
        + (directory == "" ? "/" : directory));

    if (!http.get(contentsUrl))
        fail("Не удалось получить список файлов '" + directory + "': "
            + str.toString(http.lastError()));

    if (http.status() != 200)
        fail("GitHub вернул HTTP " + str.toString(http.status())
            + " для '" + directory + "': " + http.statusText());

    var entries = null;
    try
    {
        entries = json.parse(http.getResponse());
    }
    catch (e)
    {
        fail("Не удалось разобрать GitHub JSON для '" + directory + "': "
            + str.toString(e));
    }

    if (entries == null or typeName(entries) != "array")
        fail("GitHub вернул не массив файлов для '" + directory + "'");

    print("  HTTP " + str.toString(http.status()) + ", элементов: "
        + str.toString(entries.size()) + ", время: "
        + str.toString((system.gettickcount() - requestStartedAt) / 1000.0)
        + " сек");

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

        // Нормализуем CRLF в LF так же, как Git при хранении текстовых файлов.
        var hashStartedAt = system.gettickcount();
        var normalizedBytes = ByteArray();
        for (var [byteIndex, currentByte] : localBytes)
        {
            if (currentByte == 13 and byteIndex + 1 < localBytes.size()
                and localBytes[byteIndex + 1] == 10)
                continue;

            normalizedBytes.push(currentByte);
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
            changed.push("изменён: " + path + " (локальный SHA " + localSha
                + ", GitHub SHA " + remoteSha + ")");

        print("  SHA " + path + ": "
            + str.toString((system.gettickcount() - hashStartedAt) / 1000.0)
            + " сек");
    }
}

print("");
print("Проверка завершена: запросов к GitHub — " + str.toString(requestCount)
    + ", файлов проверено — " + str.toString(checked)
    + ", общее время — "
    + str.toString((system.gettickcount() - testStartedAt) / 1000.0) + " сек");

if (changed.empty())
{
    print("Расхождений нет: локальные файлы соответствуют GitHub.");
    return 0;
}

print("Найдены расхождения: " + str.toString(changed.size()));
for (var difference : changed)
    print("- " + str.toString(difference));

return 0;
