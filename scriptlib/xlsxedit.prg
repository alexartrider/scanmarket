// xlsxedit.prg — высокоуровневый пайплайн XLSX на Qt-версии qt.XlsxDocument (OpenXLSX/QXlsx).
//
// Подключение (loadModule оставляет модуль в Script::Modules):
//   loadModule(file.normalize(file.join(file.dirname(system.getcommandline().app), "..", "scriptlib", "xlsxedit.prg")));
//
// API (namespace xlsxedit):
//   xlsxedit.create(path)                        — новый документ (перезаписывает) → doc
//   xlsxedit.open(path)                          — открыть существующий → doc (не найден — исключение)
//   xlsxedit.writeMatrix(doc, rows, [sr, sc])    — массив массивов (1-based, по умолчанию sr=sc=1)
//   xlsxedit.readMatrix(doc)                     — все строки текущего листа (1-based, до rowCount/columnCount)
//   xlsxedit.appendRow(doc, row)                 — дописать строку после последней → номер строки
//   xlsxedit.findRow(doc, col, value)            — номер первой строки со значением в столбце (или null)
//   xlsxedit.save(doc, [path])                   — save() или saveAs(path)
// Листы — как в XlsxDocument: selectSheet(name|index), addSheet, sheetNames, …
// Все проверки с понятным исключением (аналог "assert"), ничего не мутируется молча.

var xlsxedit = #tuple{};

function __xe_require(cond, msg) { if (!cond) throw "xlsxedit: " + msg; }

xlsxedit.create = function(path) {
    var d = qt.XlsxDocument();
    __xe_require(d.create(path), "не удалось создать " + path);
    return d;
};

xlsxedit.open = function(path) {
    var d = qt.XlsxDocument();
    __xe_require(d.open(path), "не удалось открыть " + path);
    return d;
};

xlsxedit.save = function(doc, path) {
    __xe_require(doc != null, "save: документ не передан");
    if (path == null) { __xe_require(doc.save(), "не удалось сохранить"); return 1; }
    __xe_require(doc.saveAs(path), "не удалось сохранить как " + path);
    return 1;
};

xlsxedit.writeMatrix = function(doc, rows, startRow, startCol) {
    __xe_require(doc != null, "writeMatrix: документ не передан");
    __xe_require(rows != null, "writeMatrix: ожидается массив строк");
    var r0 = (startRow == null) ? 1 : startRow;
    var c0 = (startCol == null) ? 1 : startCol;
    var written = 0;
    for (var r = 0; r < rows.size(); r++) {
        var row = rows[r];
        for (var c = 0; c < row.size(); c++) {
            doc.write(r0 + r, c0 + c, row[c]);
            written++;
        }
    }
    return written;
};

xlsxedit.readMatrix = function(doc) {
    __xe_require(doc != null, "readMatrix: документ не передан");
    var out = #[];
    var n = doc.rowCount();
    var m = doc.columnCount();
    for (var r = 1; r <= n; r++) {
        var row = #[];
        for (var c = 1; c <= m; c++) row.push(doc.read(r, c));
        out.push(row);
    }
    return out;
};

xlsxedit.appendRow = function(doc, row) {
    __xe_require(doc != null, "appendRow: документ не передан");
    var r = doc.rowCount() + 1;
    for (var c = 0; c < row.size(); c++) doc.write(r, c + 1, row[c]);
    return r;
};

xlsxedit.findRow = function(doc, col, value) {
    __xe_require(doc != null, "findRow: документ не передан");
    var n = doc.rowCount();
    for (var r = 1; r <= n; r++) {
        var v = doc.read(r, col);
        if (str.toString(v) == str.toString(value)) return r;
    }
    return null;
};
