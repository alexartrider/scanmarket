// scanutils.prg — CLI утилита диагностики
// Запуск: bin\qode.exe tools\scanutils.prg <command> [args]
// Commands:
//   tail [n] [path]        — last n lines of newest log
//   clean [n] [path]       — last n lines, noise collapsed
//   grep <pattern> [path]  — lines containing pattern
//   db                     — DB summary
//   runs [n]               — scan_runs listing
//   points [n]             — recent price_points with names
//   fixstale               — close dangling scan_runs as stale
//   cookies [path]         — cookies.json summary
//   dump [path]            — HTML dump anti-bot markers
//   procs [marker]         — browser processes
//   readme <sectionfile> [readme] — append markdown section to README (idempotent)
//   readmeinfo [path]      — README stats + headings list
//   cleanroot [hours] [run] — remove one-off root .prg older than hours (default dry)
//   movefile <src> <dst>   — move a file
//   caps                   — capability check (regex/sqlite/wmi)

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
projectDir = file.dirname(projectDir);
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/scanutil.prg");

var cl = system.getcommandline();
var args = #[];
if (cl != null and coalesce(cl.count, 0) > 1) {
    for (var i = 1; i < cl.args.size(); i++) args.push(cl.args.get(i));
}

var cmd = args.size() > 0 ? str.toString(args.get(0)) : "";
var a1 = args.size() > 1 ? str.toString(args.get(1)) : "";
var a2 = args.size() > 2 ? str.toString(args.get(2)) : "";

function toInt(v, def) {
    if (v == null or v == "") return def;
    var n = str.toInt(v);
    return n == null ? def : n;
}

if (cmd == "tail") {
    print(tailLog(a2, toInt(a1, 40)));
} else if (cmd == "clean") {
    print(tailLogClean(a2, toInt(a1, 60)));
} else if (cmd == "grep") {
    if (a1 == "") { print("usage: grep <pattern> [path]"); }
    else print(grepLog(a2, a1));
} else if (cmd == "db") {
    var db = dbOpen(null);
    print(dbSummary(db));
    if (db != null) db.close();
} else if (cmd == "runs") {
    var db2 = dbOpen(null);
    print(dbRunsList(db2, toInt(a1, 20)));
    if (db2 != null) db2.close();
} else if (cmd == "points") {
    var db3 = dbOpen(null);
    print(dbPointsList(db3, toInt(a1, 20)));
    if (db3 != null) db3.close();
} else if (cmd == "fixstale") {
    var db4 = dbOpen(null);
    if (db4 == null) print("DB missing");
    else {
        var n = dbCloseDangling(db4);
        print("stale closed=" + str.toString(n));
        print(dbSummary(db4));
        db4.close();
    }
} else if (cmd == "cookies") {
    print(cookiesInfo(a1));
} else if (cmd == "dump") {
    print(dumpInfo(a1));
} else if (cmd == "procs") {
    print(procList(a1));
} else if (cmd == "readme") {
    var r = readmeAppendSection(a1, a2);
    print("readmeAppendSection=" + str.toString(r));
} else if (cmd == "readmeinfo") {
    print(readmeInfo(a1));
} else if (cmd == "cleanroot") {
    var mode = true;
    if (a2 == "run") mode = false;
    print(cleanRoot(null, toInt(a1, 2), mode));
} else if (cmd == "movefile") {
    print("moved=" + str.toString(moveFile(a1, a2)));
} else if (cmd == "caps") {
    print("splitlines=" + str.toString("a\nb".splitlines().size()));
    print("regexfindall=" + str.toString("a1b22c333".regexfindall("[0-9]+")));
    print("regexreplace=" + "x<y>".regexreplace("<[^>]+>", " "));
    print("parse=" + str.toString(datetime.parse("2026-11-04 06:00:00", "%Y-%m-%d %H:%M:%S")));
    print("sqlite=" + str.toString(sqlite.version()));
    print("wmi=" + str.toString(system.wmi.processes() != null));
    print("jsonPretty=" + jsonPretty(#["x", 1]));
} else {
    print("usage: bin\qode.exe tools\scanutils.prg <tail|clean|grep|db|runs|points|fixstale|cookies|dump|procs|readme|readmeinfo|cleanroot|movefile|caps> [args]");
}

return 0;
