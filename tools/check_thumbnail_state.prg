// Read-only диагностика снимка и товаров без миниатюр в SQLite.
uses db;

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");

var cfg = loadConfig("");
var snapPath = "private_data/ozon/ozon_last_scan.json";
var raw = file.read(snapPath, file.ENC_UTF8_BOM);
var withImage = 0;
var total = 0;

if (raw != null and raw != "") {
    var snap = json.parse(raw);
    if (snap != null and snap.has("items")) {
        for (var item : snap.items) {
            total++;
            var image = str.toString(coalesce(item.get("image"), ""));
            if (image != "") withImage++;
        }
    }
}
print("Снимок: товаров=\(str.toString(total)), с URL изображения=\(str.toString(withImage))");

var dbFile = file.absolute(cfgGet(cfg, "db.path", "private_data/ozon/ozon.sqlite"));

db.connect(db.QSQLITE, dbFile);
if (!db.active)
    throw "Не удалось открыть SQLite: \(dbFile)";

var q = db.query();

q.open("pragma table_info(products)");
var hasThumbnail = false;

while (!q.eof()) {
    if (str.toString(q.field(1)) == "thumbnail") hasThumbnail = true;
    q.next();
}

q.close();

if (hasThumbnail) {
    q.open(
        "select count(*), " +
        "sum(case when thumbnail is not null then 1 else 0 end), " +
        "sum(case when thumbnail_url like 'https://ir%.ozone.ru/s3/multimedia-%' then 1 else 0 end), " +
        "sum(case when thumbnail_url like 'https://cdn%.ozonusercontent.com/s3/%' then 1 else 0 end) " +
        "from products where source = 'ozon'"
    );

    if (!q.eof()) {
        print(
            "SQLite: товаров=\(str.toString(q.field(0)))" +
            ", с BLOB=\(str.toString(coalesce(q.field(1), 0)))" +
            ", URL основной фотографии=\(str.toString(coalesce(q.field(2), 0)))" +
            ", URL CDN-значка=\(str.toString(coalesce(q.field(3), 0)))"
        );
    }

    q.close();

    q.open(
        "select product_id, coalesce(name, ''), coalesce(best_url, '') " +
        "from products " +
        "where source = 'ozon' and thumbnail is null " +
        "order by name collate nocase"
    );

    var missingCount = 0;

    while (!q.eof()) {
        missingCount++;
        print(
            "Без BLOB: id=\(str.toString(q.field(0)))" +
            " | \(str.toString(q.field(1)))" +
            " | URL=\(str.toString(q.field(2)))"
        );
        q.next();
    }

    print("Товаров без BLOB: \(str.toString(missingCount))");
    q.close();
} else {
    print("SQLite: столбца products.thumbnail пока нет");
}

db.disconnect();
return 0;
