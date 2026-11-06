// scanutil.prg — диагностика утилит (логи, база данных SQLite,
// cookies, дамп HTML, процессы).
//
// Использование:
// loadModule("lib/scanutil.prg");
// После загрузки экспортируемые функции регистрируются глобально,
// поэтому их можно вызывать напрямую: tailLog, dbSummary и т. д.
//
// Запуск утилиты из командной строки:
// bin\qode.exe tools\scanutils.prg <command> [args]

var logDirName = "bin/log";
var dbDefault = "private_data/ozon/ozon.sqlite";
var cookiesDefault = "private_data/ozon/ozon_cookies.json";

// ---------- logs ----------

function newestLogFile(dir) export {
    if (dir == null) dir = logDirName;
    var fs = null;
    try { fs = file.dir(dir, "*.log"); } catch (e) { return null; }
    if (fs == null or fs.size() == 0) return null;
    var best = "";
    var bestKey = "";
    for (var f : fs) {
        var nm = str.toString(f);
        var p = file.join(dir, nm);
        if (!file.isfile(p)) continue;
        var key = nm;
        var dot = str.pos(nm, ".log");
        if (dot > 0) {
            var body = str.sub(nm, 0, dot);
            var bpos = str.pos(body, "_");
            if (bpos > 0) {
                var ds = str.sub(body, bpos + 1, str.len(body) - bpos - 1);
                if (str.len(ds) >= 8) key = str.sub(ds, 4, 4) + str.sub(ds, 2, 2) + str.sub(ds, 0, 2);
            }
        }
        if (key >= bestKey) { bestKey = key; best = p; }
    }
    if (best == "") best = file.join(dir, str.toString(fs.get(fs.size() - 1)));
    return best;
}

function logLines(path) export {
    if (path == null or path == "") path = newestLogFile(null);
    if (path == null or !file.isfile(path)) return null;
    var txt = file.read(path, file.ENC_CP1251);
    if (txt == null) return null;
    return txt.splitlines();
}

function tailLog(path, count) export {
    var ls = logLines(path);
    if (ls == null) return "";
    if (count == null or count < 1) count = 40;
    var from = ls.size() - count;
    if (from < 0) from = 0;
    var out = "";
    for (var i = from; i < ls.size(); i++) out += str.toString(ls.get(i)) + "\n";
    return out;
}

function isNoiseLine(s) export {
    if (s == null) return false;
    if (s.regexsearch("ready wait \d+:")) return true;
    if (s.regexsearch("Ожидание карточек, попытка \d+:")) return true;
    if (s.regexsearch("CDP: ")) return true;
    if (s.regexsearch("dump chunk \d+")) return true;
    if (s.regexsearch("Загрузка страницы")) return true;
    if (s.regexsearch("Страница загружена")) return true;
    if (s.regexsearch("проверочная страница Ozon")) return true;
    return false;
}

function tailLogClean(path, count) export {
    var ls = logLines(path);
    if (ls == null) return "";
    if (count == null or count < 1) count = 60;
    var keep = #[];
    var run = 0;
    for (var i = 0; i < ls.size(); i++) {
        var s = str.toString(ls.get(i));
        if (isNoiseLine(s)) { run++; continue; }
        if (run > 0) { keep.push("   ... [" + str.toString(run) + " noise lines collapsed]"); run = 0; }
        keep.push(s);
    }
    if (run > 0) keep.push("   ... [" + str.toString(run) + " noise lines collapsed]");
    var from = keep.size() - count;
    if (from < 0) from = 0;
    var out = "";
    for (var i = from; i < keep.size(); i++) out += str.toString(keep.get(i)) + "\n";
    return out;
}

function grepLog(path, pattern) export {
    var ls = logLines(path);
    if (ls == null) return "";
    var out = "";
    for (var i = 0; i < ls.size(); i++) {
        var s = str.toString(ls.get(i));
        if (s.contains(pattern)) out += s + "\n";
    }
    return out;
}

function grepLogMany(path, patterns) export {
    var ls = logLines(path);
    if (ls == null) return "";
    var out = "";
    for (var p : patterns) {
        var pat = str.toString(p);
        for (var i = 0; i < ls.size(); i++) {
            var s = str.toString(ls.get(i));
            if (s.contains(pat)) out += s + "\n";
        }
    }
    return out;
}

// ---------- SQLite ----------

function dbOpen(path) export {
    if (path == null or path == "") path = dbDefault;
    if (!file.isfile(path)) return null;
    try { return sqlite.open(path); } catch (e) { return null; }
}

function dbScalar(db, sql) export {
    if (db == null) return null;
    try { return db.scalar(sql); } catch (e) { return null; }
}

function dbRows(db, sql, params) export {
    if (db == null) return #[];
    try {
        var rows = null;
        if (params == null) rows = db.query(sql);
        else rows = db.query(sql, params);
        if (rows == null or !rows.isarray()) return #[];
        return rows;
    } catch (e) { return #[]; }
}

// База-диагностика: колики each table + dangle-процессы
function dbSummary(db) export {
    if (db == null) return "DB unavailable";
    var products = dbScalar(db, "select count(*) as n from products");
    var points = dbScalar(db, "select count(*) as n from price_points");
    var runs = dbScalar(db, "select count(*) as n from scan_runs");
    var dangling = dbScalar(db, "select count(*) as n from scan_runs where status = 'run'");
    var stale = dbScalar(db, "select count(*) as n from scan_runs where status = 'stale'");
    var seen = dbScalar(db, "select count(distinct product_id) as n from price_points");
    var s = "products=\(str.toString(products)) price_points=\(str.toString(points)) scan_runs=\(str.toString(runs)) seen_products=\(str.toString(seen))";
    s += " dangling=\(str.toString(dangling)) stale=\(str.toString(stale))";
    var mm = dbRows(db, "select min(price) as mn, max(price) as mx from price_points");
    if (mm.size() > 0) {
        var mmn = str.toString(mm.get(0).get("mn"));
        var mmx = str.toString(mm.get(0).get("mx"));
        s += " price_min=\(mmn) price_max=\(mmx)";
    }
    var last = dbRows(db, "select max(captured_at) as cap from price_points");
    if (last.size() > 0) {
        var lastCap = str.toString(last.get(0).get("cap"));
        s += " last_captured=\(lastCap)";
    }
    return s;
}

// scan_runs (последные limit)
function dbRunsList(db, limit) export {
    if (db == null) return "";
    if (limit == null or limit < 1) limit = 20;
    var rows = dbRows(db, "select id as id, status as status, started_at as started_at, finished_at as finished_at, items_total as items_total, items_new as items_new, note as note from scan_runs order by id desc limit \(str.toString(limit))");
    var out = "";
    for (var r : rows) {
        var rId = str.toString(r.get("id"));
        var rStatus = str.toString(r.get("status"));
        var rStart = str.toString(r.get("started_at"));
        var rEnd = str.toString(r.get("finished_at"));
        var rTotal = str.toString(r.get("items_total"));
        var rNew = str.toString(r.get("items_new"));
        var rNote = str.toString(r.get("note"));
        out += "  #\(rId) \(rStatus) start=\(rStart) end=\(rEnd) total=\(rTotal) new=\(rNew) note=\(rNote)\n";
    }
    return out;
}

// price_points с.names из products
function dbPointsList(db, limit) export {
    if (db == null) return "";
    if (limit == null or limit < 1) limit = 20;
    var names = #[];
    var all = dbRows(db, "select product_id as pid, name as nm from products");
    for (var n : all) names.push(n);
    var rows = dbRows(db, "select product_id as pid, price as price, old_price as old_price, captured_at as cap from price_points order by captured_at desc limit \(str.toString(limit))");
    var out = "";
    for (var r : rows) {
        var pid = str.toString(r.get("pid"));
        var nm = "";
        for (var n2 : names) {
            if (str.toString(n2.get("pid")) == pid) { nm = str.toString(n2.get("nm")); break; }
        }
        var cap = str.toString(r.get("cap"));
        var price = str.toString(r.get("price"));
        var oldPrice = str.toString(r.get("old_price"));
        out += "  \(cap) id=\(pid) price=\(price) old=\(oldPrice) \(nm)\n";
    }
    return out;
}

// dangle-процессы status='run' как 'stale'
function dbCloseDangling(db) export {
    if (db == null) return 0;
    var ids = dbRows(db, "select id as id, started_at as started_at from scan_runs where status = 'run'");
    var n = 0;
    for (var r : ids) {
        var rid = r.get("id");
        try {
            db.exec("update scan_runs set finished_at = started_at, status = 'stale', note = 'stale closed by util' where id = ?", #[rid]);
            n++;
        } catch (e) { }
    }
    return n;
}

// ---------- cookies / json ----------

function jsonPretty(obj, indent) export {
    if (obj == null) return "null";
    if (indent == null) return json.stringify(obj);
    return json.stringify(obj, true, indent);
}

// Куки: колики, names, domains, expires, sameSite
function cookiesInfo(path) export {
    if (path == null or path == "") path = cookiesDefault;
    if (!file.isfile(path)) return "cookies: file missing \(path)";
    var raw = file.read(path, file.ENC_UTF8_BOM);
    if (raw == null) return "cookies: read failed \(path)";
    if (raw.size() > 0 and str.ord(raw) == 0xFEFF) raw = str.sub(raw, 1);
    var data = null;
    try { data = json.parse(raw); } catch (e) { return "cookies: parse failed \(str.toString(e))"; }
    if (data == null or !data.isarray()) return "cookies: not array";
    var names = #[];
    var domains = #[];
    var exps = #[];
    var sites = #[];
    for (var c : data) {
        if (c == null or !c.iscontainer()) continue;
        var nm = str.toString(coalesce(c.get("name"), ""));
        if (nm != "" and !names.contains(nm)) names.push(nm);
        var dm = str.toString(coalesce(c.get("domain"), ""));
        if (dm != "" and !domains.contains(dm)) domains.push(dm);
        if (c.get("expires") != null) {
            var ex = str.toString(c.get("expires"));
            if (!exps.contains(ex)) exps.push(ex);
        }
        if (c.get("sameSite") != null) {
            var ss = str.toString(c.get("sameSite"));
            if (!sites.contains(ss)) sites.push(ss);
        }
    }
    var s = "cookies: \(str.toString(data.size()))\n";
    s += "domains (\(str.toString(domains.size()))): \(str.toString(domains))\n";
    s += "sameSite: \(str.toString(sites))\n";
    var sample = "";
    for (var i = 0; i < exps.size() and i < 10; i++) {
        if (i > 0) sample += ", ";
        sample += str.toString(exps.get(i));
    }
    s += "expires sample: \(sample)\n";
    s += "names (\(str.toString(names.size()))): \(str.toString(names))\n";
    return s;
}

// ---------- HTML dump (anti-bot markers) ----------

function htmlText(html) export {
    if (html == null) return "";
    var t = html.regexreplace("<script(.|\n)*?</script>|<style(.|\n)*?</style>", " ");
    t = t.regexreplace("<[^>]+>", "\n");
    var ls = t.splitlines();
    var out = "";
    for (var i = 0; i < ls.size(); i++) {
        var s = str.trim(str.toString(ls.get(i)));
        if (s == "") continue;
        out += s + "\n";
    }
    return out;
}

function htmlTitle(html) export {
    if (html == null or !html.isstring()) return "";
    var found = html.regexfindall("<title[^>]*>([^<]*)</title>");
    if (found == null or !found.isarray() or found.size() == 0) return "";
    var first = found.get(0);
    if (first.isarray()) {
        if (first.size() > 1) return str.trim(str.toString(first.get(1)));
        if (first.size() > 0) return str.trim(str.toString(first.get(0)));
        return "";
    }
    return str.trim(str.toString(first));
}

function dumpInfo(path) export {
    if (path == null or path == "") return "dump: no path";
    if (!file.isfile(path)) return "dump: missing \(path)";
    var html = file.read(path, file.ENC_UTF8_BOM);
    if (html == null) return "dump: read failed";
    if (html.size() > 0 and str.ord(html) == 0xFEFF) html = str.sub(html, 1);
    var low = str.lower(html);
    var s = "title: \(htmlTitle(html))\n";
    for (var key : #["fab_chlg", "incident", "captcha", "antibot", "unreachable", "sorry", "proxy", "vpn"]) {
        var k = str.pos(low, key);
        if (k < 0) continue;
        var frag = str.sub(html, k, 160);
        s += key + ": " + str.replace(str.replace(frag, "\n", " "), "\r", " ") + "\n";
    }
    var txt = htmlText(html);
    var ls = txt.splitlines();
    s += "--- visible text (\(str.toString(ls.size())) lines) ---\n";
    for (var i = 0; i < ls.size() and i < 60; i++) s += str.toString(ls.get(i)) + "\n";
    return s;
}

// ---------- processes ----------

function procList(marker) export {
    var procs = null;
    try { procs = system.wmi.processes(); } catch (e) { return "process list unavailable: \(str.toString(e))"; }
    if (procs == null or !procs.isarray()) return "process list unavailable";
    var mk = "";
    if (marker != null) mk = str.lower(str.toString(marker));
    var out = "";
    var n = 0;
    for (var p : procs) {
        if (p == null) continue;
        var nm = str.lower(str.toString(coalesce(p.Name, "")));
        var cmd = str.toString(coalesce(p.CommandLine, ""));
        var low = str.lower(cmd);
        if (mk != "" and !low.contains(mk) and !nm.contains(mk)) continue;
        if (mk == "" and !nm.contains("browser")) continue;
        n++;
        out += "  pid=\(str.toString(p.ProcessId)) \(str.toString(p.Name)) \(cmd)\n";
    }
    return "matched=\(str.toString(n))\n\(out)";
}

// ---------- readme section ----------

// Добавить раздел Markdown из файла в README.
// Возвращает 1, если раздел добавлен; 0, если он уже есть; -1 при ошибке ввода-вывода.
function readmeAppendSection(sectionPath, readmePath) export {
    if (readmePath == null or readmePath == "") readmePath = "README.md";
    if (!file.isfile(sectionPath)) return -1;
    if (!file.isfile(readmePath)) return -1;
    var sec = file.read(sectionPath, file.ENC_UTF8_BOM);
    if (sec == null) return -1;
    if (sec.size() > 0 and str.ord(sec) == 0xFEFF) sec = str.sub(sec, 1);
    sec = str.replace(sec, "\r\n", "\n");
    sec = str.replace(sec, "\r", "\n");
    sec = str.replace(sec, "\n", "\r\n");
    sec = str.trim(sec);
    if (sec == "") return -1;
    var cur = file.read(readmePath, file.ENC_UTF8_BOM);
    if (cur == null) return -1;
    var lines = sec.splitlines();
    var head = lines.size() > 0 ? str.trim(str.toString(lines.get(0))) : "";
    if (head != "" and cur.contains(head)) {
        print("readme: section already present, skipped: \(head)");
        return 0;
    }
    var added = file.append(readmePath, "\r\n" + sec + "\r\n", file.ENC_UTF8_NO_BOM);
    if (added == null or !added) {
        print("readme: append failed \(readmePath)");
        return -1;
    }
    print("readme: appended \(str.toString(str.len(sec) + 4)) chars");
    return 1;
}

// README: size, BOM ли, lines, h1/h2 headings
function readmeInfo(path) export {
    if (path == null or path == "") path = "README.md";
    if (!file.isfile(path)) return "readme: missing " + path;
    var cur = file.read(path, file.ENC_UTF8_BOM);
    if (cur == null) return "readme: read failed";
    var bom = str.fromCharCode(0xFEFF);
    var crlfCount = str.count(cur, "\r\n");
    var s = "readme: \(path) chars=\(str.toString(str.len(cur))) bom_first=\(str.toString(str.ord(cur) == 0xFEFF))";
    s += " bom_count=\(str.toString(str.count(cur, bom))) crlf=\(str.toString(crlfCount))";
    var ls = cur.splitlines();
    var heads = "";
    var hn = 0;
    for (var i = 0; i < ls.size(); i++) {
        var t = str.trim(str.toString(ls.get(i)));
        if (!str.startswith(t, "#")) continue;
        hn++;
        if (hn <= 40) heads += "  [\(str.toString(i + 1))] \(t)\n";
    }
    s += " headings=\(str.toString(hn))\n\(heads)";
    return s;
}

// ---------- root cleanup ----------

// core scripts, configs, docs, binaries
var rootKeepList = #["ozon_scan.prg", "ozon_auth.prg", "ozon_check_session.prg", "ozon_setup_cron.prg", "checkload.prg", "config.json", "README.md", "AGENTS.md", "scan_ozon.bat"];

// Remove one-off diagnostic scripts older than N hours
// dryRun default true — проелл only. Returns report string
function cleanRoot(dir, hours, dryRun, keepMore) export {
    if (dir == null or dir == "") dir = ".";
    if (hours == null or hours < 0) hours = 2;
    var dry = true;
    if (dryRun != null) dry = dryRun;
    var names = null;
    try { names = file.dir(dir, "*.prg"); } catch (e) { return "cleanroot: dir listing failed"; }
    if (names == null or !names.isarray()) return "cleanroot: no files";
    var nowTs = datetime.timestamp(datetime.now());
    var out = "";
    var nDel = 0;
    var nKeep = 0;
    for (var f : names) {
        var nm = str.toString(f);
        var p = file.join(dir, nm);
        if (!file.isfile(p)) continue;
        if (rootKeepList.contains(nm) or (keepMore != null and keepMore.contains(nm))) { nKeep++; continue; }
        var mt = null;
        try { mt = file.mtime(p); } catch (e) { mt = null; }
        if (mt == null) { nKeep++; continue; }
        var ageH = (nowTs - datetime.timestamp(mt)) / 3600;
        if (ageH < hours) { nKeep++; continue; }
        var sz = file.size(p);
        if (dry) {
            out += "  would remove \(p) age_h=\(str.toString(ageH)) size=\(str.toString(sz))\n";
            nDel++;
            continue;
        }
        var ok = false;
        try { ok = file.remove(p) == true; } catch (e) { ok = false; }
        if (!ok) out += "  remove FAILED \(p)\n";
        else out += "  removed \(p) age_h=\(str.toString(ageH)) size=\(str.toString(sz))\n";
        nDel++;
    }
    return "cleanroot: dir=\(dir) hours=\(str.toString(hours)) dry=\(str.toString(dry)) candidates=\(str.toString(nDel)) kept=\(str.toString(nKeep))\n\(out)";
}

// Move file
function moveFile(src, dst) export {
    if (src == null or dst == null) return false;
    if (!file.isfile(src)) return false;
    return file.move(src, dst) == true;
}
