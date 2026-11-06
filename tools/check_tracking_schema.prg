// Read-only проверка колонок и состояния отслеживания в SQLite.
uses db;

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");

var cfg = loadConfig("");
var dbFile = file.absolute(cfgGet(cfg, "db.path", "private_data/ozon/ozon.sqlite"));

db.connect(db.QSQLITE, dbFile);

if (!db.active)
    throw "Не удалось подключиться к SQLite: " + dbFile;

var schema = db.query();
schema.open("pragma table_info(products)");

var hasTrackingEnabled = false;
var hasFavoriteState = false;
var hasThumbnail = false;
var hasThumbnailUrl = false;

while (!schema.eof())
{
    var columnName = str.toString(schema.field(1));

    if (columnName == "tracking_enabled")
        hasTrackingEnabled = true;

    if (columnName == "favorite_state")
        hasFavoriteState = true;

    if (columnName == "thumbnail")
        hasThumbnail = true;

    if (columnName == "thumbnail_url")
        hasThumbnailUrl = true;

    schema.next();
}

schema.close();

print("tracking_enabled=\(str.toString(hasTrackingEnabled))");
print("favorite_state=\(str.toString(hasFavoriteState))");
print("thumbnail=\(str.toString(hasThumbnail))");
print("thumbnail_url=\(str.toString(hasThumbnailUrl))");

if (!hasTrackingEnabled or !hasFavoriteState or !hasThumbnail or !hasThumbnailUrl)
    throw "В SQLite отсутствует одно или несколько ожидаемых полей";

var q = db.query();
q.open(
    "select product_id, tracking_enabled, favorite_state, status " +
    "from products where source = 'ozon' " +
    "and product_id in ('2965671696', '3799628410') " +
    "order by product_id"
);

while (!q.eof())
{
    print(
        "ID=\(str.toString(q.field(0)))" +
        " tracking=\(str.toString(q.field(1)))" +
        " favorite=\(str.toString(q.field(2)))" +
        " status=\(str.toString(q.field(3)))"
    );
    q.next();
}

q.close();
db.disconnect();
return 0;
