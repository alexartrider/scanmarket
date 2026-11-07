// Безопасная проверка execArgvAsync без запуска браузера и изменения профиля.
// Запуск: bin\qodeqt.exe test\check_execargv_async.prg

var executable = file.join(
    coalesce(file.getenv("SystemRoot"), "C:\\Windows"),
    "System32",
    "whoami.exe"
);

if (!file.exists(executable)) {
    print("whoami.exe не найден: " + executable);
    return 1;
}

var process = system.execArgvAsync(
    #[executable],
    #{"timeout": 30000, "console": "detached"}
);

var deadline = system.gettickcount() + 10000;
while (!process.isReady and system.gettickcount() < deadline)
    system.sleep(0.05);

if (!process.isReady) {
    process.kill();
    print("execArgvAsync не завершил whoami.exe за 10 секунд");
    return 1;
}

var result = process.result;
if (result == null or result.get("success") != true or result.get("code") != 0) {
    print("execArgvAsync завершился с ошибкой: " + str.toString(result));
    return 1;
}

print("execArgvAsync detached OK");
return 0;
