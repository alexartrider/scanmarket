// dbstore.prg — база цен в SQLite через qt-адаптер (модуль db)
// Обращение: loadModule("lib/dbstore.prg"); затем storeConnect(path), upsertProduct(...) и т.д.

uses db;
uses math;

var dbPath = file.absolute(file.join("private_data", "ozon", "ozon.sqlite"));
var source = "ozon";

function storeConnect(path) export {
    if (path != null and path != "") dbPath = file.absolute(path);
    file.mkdirrecursive(file.dirname(dbPath));
    db.connect(db.QSQLITE, dbPath);
    if (!db.active) throw "Не удалось подключиться к SQLite: " + dbPath;
    ensureSchema();
    print("База данных: \(dbPath)");
    return true;
}

function ensureSchema() {
    var q = db.query();
    q.execSQL("create table if not exists products (source text, product_id text, name text, brand text, best_url text, status text, created_at text, updated_at text, primary key(source, product_id))");
    q.close();
    var cols = db.query();
    cols.open("pragma table_info(products)");
    var hasThumbnail = false;
    while (!cols.eof()) {
        if (str.toString(cols.field(1)) == "thumbnail") hasThumbnail = true;
        cols.next();
    }
    cols.close();
    if (!hasThumbnail) {
        var migrateThumb = db.query();
        migrateThumb.execSQL("alter table products add column thumbnail blob");
        migrateThumb.close();
    }
    var sourceCol = db.query();
    sourceCol.open("pragma table_info(products)");
    var hasThumbnailUrl = false;
    while (!sourceCol.eof()) {
        if (str.toString(sourceCol.field(1)) == "thumbnail_url") hasThumbnailUrl = true;
        sourceCol.next();
    }
    sourceCol.close();
    if (!hasThumbnailUrl) {
        var migrateUrl = db.query();
        migrateUrl.execSQL("alter table products add column thumbnail_url text");
        migrateUrl.close();
    }

    var trackingCols = db.query();
    trackingCols.open("pragma table_info(products)");

    var hasTrackingEnabled = false;
    var hasFavoriteState = false;

    while (!trackingCols.eof()) {
        var columnName = str.toString(trackingCols.field(1));
        if (columnName == "tracking_enabled") hasTrackingEnabled = true;
        if (columnName == "favorite_state") hasFavoriteState = true;
        trackingCols.next();
    }

    trackingCols.close();

    if (!hasTrackingEnabled) {
        var migrateTracking = db.query();
        migrateTracking.execSQL(
            "alter table products add column tracking_enabled integer not null default 1"
        );
        migrateTracking.close();
    }

    if (!hasFavoriteState) {
        var migrateFavoriteState = db.query();
        migrateFavoriteState.execSQL(
            "alter table products add column favorite_state text not null default 'unknown'"
        );
        migrateFavoriteState.close();
    }

    q.execSQL("create table if not exists price_points (id integer primary key autoincrement, source text, product_id text, price real, old_price real, currency text, status text, captured_at text)");
    q.execSQL("create index if not exists ix_price_points on price_points(source, product_id, captured_at)");
    q.execSQL("create table if not exists scan_runs (id integer primary key autoincrement, started_at text, finished_at text, source text, items_total int, items_new int, status text, note text)");
    q.close();
}

// Проверяет наличие сохранённой миниатюры, не загружая BLOB в память.
function hasThumbnail(productId, imageUrl) export {
    var q = db.query();
    q.open("select thumbnail is not null and thumbnail_url = ? from products where source = ? and product_id = ?",
        #[str.toString(coalesce(imageUrl, "")), source, str.toString(productId)]);
    var found = !q.eof() and q.field(0) == 1;
    q.close();
    return found;
}

// Проверяет, есть ли товар в нашей базе; используется для отбора известных товаров
// из блока рекомендаций Ozon без добавления посторонних рекомендаций.
function trackedProductExists(productId) export {
    if (productId == null or productId == "")
        return false;

    var q = db.query();
    q.open(
        "select 1 from products " +
        "where source = ? and product_id = ? " +
        "limit 1",
        #[source, str.toString(productId)]
    );

    var found = !q.eof();
    q.close();

    return found;
}

function trackedProductForFavoriteScan(productId) export {
    if (productId == null or productId == "")
        return null;

    var q = db.query();
    q.open(
        "select coalesce(tracking_enabled, 1), coalesce(favorite_state, 'unknown') " +
        "from products " +
        "where source = ? and product_id = ? " +
        "limit 1",
        #[source, str.toString(productId)]
    );

    if (q.eof())
    {
        q.close();
        return null;
    }

    var enabled = (q.field(0) != 0);
    var favoriteState = str.toString(q.field(1));
    q.close();

    return #{"enabled": enabled, "favorite_state": favoriteState};
}

function setProductTracking(productId, enabled) export {
    if (productId == null or productId == "")
        return false;

    var value = enabled ? 1 : 0;
    var q = db.query();
    q.execSQL(
        "update products set tracking_enabled = ? " +
        "where source = ? and product_id = ?",
        #[value, source, str.toString(productId)]
    );

    var updated = q.rowsaffected() == 1;
    q.close();

    return updated;
}

// Обновляет членство избранного только после полного успешного сканирования.
function markFavoriteMembership(productIds) export {
    var q = db.query();
    q.open(
        "select product_id, coalesce(tracking_enabled, 1) " +
        "from products where source = ?",
        #[source]
    );

    var missingIds = #[];
    var favoriteIds = #[];

    while (!q.eof()) {
        var productId = str.toString(q.field(0));
        var trackingEnabled = (q.field(1) != 0);
        var foundInScan = false;

        for (var scannedId : productIds) {
            if (str.toString(scannedId) == productId)
                foundInScan = true;
        }

        if (foundInScan)
            favoriteIds.push(productId);
        else
            missingIds.push(productId);

        q.next();
    }

    q.close();

    for (var favoriteId : favoriteIds)
        setProductFavoriteState(favoriteId, "in_favorites");

    for (var missingId : missingIds)
        setProductFavoriteState(missingId, "not_in_favorites");

    return favoriteIds.size() + missingIds.size();
}

// Записывает изображение, если оно отсутствует или сменился URL источника.
// Возвращает true только если обновлена ровно одна строка.
function saveThumbnailIfChanged(productId, imageUrl, pngBytes) export {
    if (productId == null or imageUrl == null or imageUrl == "" or pngBytes == null) return false;
    var q = db.query();
    q.execSQL("update products set thumbnail = ?, thumbnail_url = ? where source = ? and product_id = ? and (thumbnail is null or thumbnail_url is null or thumbnail_url <> ?)",
        #[pngBytes, str.toString(imageUrl), source, str.toString(productId), str.toString(imageUrl)]);
    var saved = q.rowsaffected() == 1;
    q.close();
    return saved;
}

// Экранирование значений для SQL выполняет встроенная функция str.quoted.
// Для null она возвращает текст 'null', поэтому null отдельно преобразуется в пустую строку.
// NB: str.quoted("") == "''", str.quoted("a'b") == "'a''b'", str.quoted(42) == "'42'"
//     str.quoted(null) == "'null'", поэтому обработка null выше возвращает "''".
function sqlq(v) {
    if (v == null) return "''";
    return str.quoted(v);
}

function nowSql() {
    return datetime.strftime(datetime.now(), "%Y-%m-%d %H:%M:%S");
}

// Создать или обновить карточку товара
function upsertProduct(productId, name, brand, url, status, favoriteState) export {
    var now = nowSql();
    var srcQ = sqlq(source);
    var idQ = sqlq(productId);
    var nameQ = sqlq(name);
    var brandQ = sqlq(brand);
    var urlQ = sqlq(url);
    var stQ = sqlq(status);
    var q = db.query();
    q.execSQL(
        "insert or ignore into products(" +
        "source, product_id, name, brand, best_url, status, " +
        "tracking_enabled, created_at, updated_at) " +
        "values(\(srcQ), \(idQ), \(nameQ), \(brandQ), \(urlQ), \(stQ), " +
        "1, '\(now)', '\(now)')"
    );
    q.execSQL(
        "update products set " +
        "name = (case when \(nameQ) <> '' then \(nameQ) else name end), " +
        "brand = (case when \(brandQ) <> '' then \(brandQ) else brand end), " +
        "best_url = (case when coalesce(best_url, '') = '' and \(urlQ) <> '' then \(urlQ) else best_url end), " +
        "status = (case when \(stQ) <> '' then \(stQ) else status end), " +
        "updated_at = '\(now)' " +
        "where source = \(srcQ) and product_id = \(idQ)"
    );
    q.close();
}

function setProductFavoriteState(productId, state) export {
    if (productId == null or productId == "" or state == null or state == "")
        return false;

    var q = db.query();
    q.execSQL(
        "update products set favorite_state = ? " +
        "where source = ? and product_id = ?",
        #[str.toString(state), source, str.toString(productId)]
    );

    var updated = q.rowsaffected() == 1;
    q.close();

    return updated;
}

// Последняя известная цена товара (или null)
function getLastPrice(productId) export {
    var srcQ = sqlq(source);
    var idQ = sqlq(productId);
    var q = db.query();
    q.open("select price from price_points where source = \(srcQ) and product_id = \(idQ) order by captured_at desc limit 1");
    var v = null;
    if (!q.eof()) v = q.field(0);
    q.close();
    return v;
}

// Точка цены: пишем только если цена изменилась. Возврат 1 — записано, 0 — без изменений
function addPricePoint(productId, price, oldPrice, currency, status) export {
    if (price == null) return 0;
    var prev = getLastPrice(productId);
    var same = false;
    if (prev != null) same = math.isclose(prev, price, 0.0000001, 0.005);
    if (same) return 0;
    var now = nowSql();
    var srcQ = sqlq(source);
    var idQ = sqlq(productId);
    var priceS = format("%.2f", price);
    var oldS = (oldPrice == null) ? "null" : format("%.2f", oldPrice);
    var curQ = sqlq((currency == null or currency == "") ? "RUB" : currency);
    var stQ = sqlq(status);
    var q = db.query();
    q.execSQL("insert into price_points(source, product_id, price, old_price, currency, status, captured_at) values(\(srcQ), \(idQ), \(priceS), \(oldS), \(curQ), \(stQ), '\(now)')");
    q.close();
    return 1;
}

// Журнал запусков: начало
function beginRun(note) export {
    var now = nowSql();
    var srcQ = sqlq(source);
    var noteQ = sqlq(note);
    var q = db.query();
    q.execSQL("insert into scan_runs(started_at, source, status, note) values('\(now)', \(srcQ), 'run', \(noteQ))");
    var id = 0;
    q.open("select max(id) from scan_runs");
    if (!q.eof()) id = q.field(0);
    q.close();
    return id;
}

// Журнал запусков: завершение
function finishRun(runId, itemsTotal, itemsNew, status) export {
    if (runId == null or runId <= 0) return;
    var now = nowSql();
    var stQ = sqlq(status);
    var tot = str.toString(coalesce(itemsTotal, 0));
    var newCnt = str.toString(coalesce(itemsNew, 0));
    var rid = str.toString(coalesce(runId, 0));
    var q = db.query();
    q.execSQL("update scan_runs set finished_at = '\(now)', items_total = \(tot), items_new = \(newCnt), status = \(stQ) where id = \(rid)");
    q.close();
}

function markStaleRuns() export {
    var q = db.query();
    var now = nowSql();
    q.execSQL("update scan_runs set finished_at = '\(now)', status = 'stale', note = 'aborted stale run' where status = 'run'");
    q.close();
}
