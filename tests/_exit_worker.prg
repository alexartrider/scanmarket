// _exit_worker.prg — вспомогательный воркер: возвращает заданный код.
// Запуск: qodeqt _exit_worker.prg <код>
var code = str.toInt(str.toString(system.getcommandline().args[1]));
return code;
