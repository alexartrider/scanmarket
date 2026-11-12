// Проверяет асинхронный запуск worker и чтение его JSON-результата.

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
{
    print("Не удалось перейти в каталог проекта");
    system.exit(1);
}

var qodePath = file.absolute("bin/qodeqt.exe");
var workerPath = file.absolute("tools/check_github_updates.prg");
var outputFile = file.tempfile();
var process = system.execArgvAsync(
    #[qodePath, workerPath, outputFile],
    #{
        "cwd": projectDir,
        "timeout": 120000,
        "console": "detached"
    }
);

if (process == null)
{
    print("Не удалось создать асинхронный процесс");
    system.exit(1);
}

while (!process.isReady)
    system.sleep(0.1);

var processResult = process.result;
if (processResult == null)
{
    print("Дочерний процесс не вернул результат");
    system.exit(1);
}

var result = null;
var resultText = "";
try
{
    resultText = str.toString(file.read(outputFile));
    result = json.parse(resultText);
}
catch (e)
{
    print("Worker не создал корректный JSON-результат: " + str.toString(e));
    system.exit(1);
}

if (processResult.get("success") != true)
{
    print("Не удалось запустить worker: "
        + str.toString(coalesce(processResult.get("stderr"), "")));
    system.exit(1);
}

if (processResult.get("code") != 0)
{
    var errorText = result == null
        ? ""
        : str.toString(coalesce(result.get("error"), ""));
    if (result == null or result.get("ok") != false
        or (str.pos(errorText, "HTTP 403") < 0
            and str.pos(errorText, "HTTP 402") < 0
            and str.pos(errorText, "HTTP 429") < 0))
    {
        print("Worker завершился неожиданной ошибкой с кодом "
            + str.toString(processResult.get("code")));
        system.exit(1);
    }

    file.remove(outputFile);
    print("Async worker OK; GitHub HTTP error обработан штатно: " + errorText);
    return 0;
}

if (result == null or result.get("ok") != true)
{
    print("Worker вернул некорректный результат");
    system.exit(1);
}

file.remove(outputFile);
print("Async worker OK; файлов проверено: " + str.toString(result.get("checked"))
    + ", расхождений: " + str.toString(result.get("changed").size()));
return 0;
