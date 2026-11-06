// Read-only проверка карточки товара в базе и последнем снимке.
uses db;

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");

var productIds = #["2965671696", "3799628410"];
var snapshotPath = "private_data/ozon/ozon_last_scan.json";
var cfg = loadConfig("");
var dbFile = file.absolute(cfgGet(cfg, "db.path", "private_data/ozon/ozon.sqlite"));

db.connect(db.QSQLITE, dbFile);

if (!db.active)
    throw "Не удалось подключиться к SQLite: " + dbFile;

var q = db.query();

for (var productId : productIds)
{
    print("Проверка ID " + productId);

    q.open(
        "select name, status, best_url, thumbnail is not null, thumbnail_url, thumbnail, " +
        "coalesce(tracking_enabled, 1), coalesce(favorite_state, 'unknown') " +
        "from products " +
        "where source = 'ozon' and product_id = ?",
        #[productId]
    );

    if (q.eof())
    {
        print("  В SQLite товар не найден");
    }
    else
    {
        print("  name=" + str.toString(q.field(0)));
        print("  status=" + str.toString(q.field(1)));
        print("  best_url=" + str.toString(q.field(2)));
        print("  has_thumbnail=" + str.toString(q.field(3)));
        print("  thumbnail_url=" + str.toString(coalesce(q.field(4), "")));
        print("  tracking_enabled=" + str.toString(q.field(6)));
        print("  favorite_state=" + str.toString(q.field(7)));

        var thumbnailBytes = q.field(5);

        if (thumbnailBytes != null and thumbnailBytes.size() >= 24)
        {
            var imageWidth = thumbnailBytes[16] * 16777216 + thumbnailBytes[17] * 65536
                + thumbnailBytes[18] * 256 + thumbnailBytes[19];
            var imageHeight = thumbnailBytes[20] * 16777216 + thumbnailBytes[21] * 65536
                + thumbnailBytes[22] * 256 + thumbnailBytes[23];

            print("  Размер PNG=" + str.toString(imageWidth) + "x" + str.toString(imageHeight));
        }
    }

    q.close();

    q.open(
        "select price, captured_at " +
        "from price_points " +
        "where source = 'ozon' and product_id = ? " +
        "order by captured_at desc, id desc " +
        "limit 1",
        #[productId]
    );

    if (!q.eof())
        print("  Последняя цена=" + str.toString(q.field(0)) + " на " + str.toString(q.field(1)));
    else
        print("  Истории цены нет");

    q.close();
}

db.disconnect();

var snapshotRaw = file.read(snapshotPath, file.ENC_UTF8_BOM);
var snapshot = null;
var snapshotValid = false;

if (snapshotRaw != null and snapshotRaw != "")
{
    try {
        snapshot = json.parse(snapshotRaw);
        snapshotValid = (snapshot != null and snapshot.has("items"));
    } catch (parseError) {
        snapshot = null;
        snapshotValid = false;
    }
}

if (!snapshotValid)
{
    print("Последний снимок не удалось прочитать");
}
else
{
    var snapshotFound = false;

    for (var item : snapshot.items)
    {
        if (str.toString(coalesce(item.get("id"), "")) == "2965671696")
        {
            snapshotFound = true;
            print("Снимок: status=" + str.toString(coalesce(item.get("status"), "")));
            print("Снимок: image=" + str.toString(coalesce(item.get("image"), "")));
        }
    }

    if (!snapshotFound)
        print("В последнем снимке избранного товара 2965671696 нет");
}
return 0;
