uses db;

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");

var cfg = loadConfig("");
var dbFile = file.absolute(cfgGet(cfg, "db.path", "private_data/ozon/ozon.sqlite"));

db.connect(db.QSQLITE, dbFile);
if (!db.active)
    throw "Не удалось подключиться к SQLite";

var q = db.query();
q.open(
    "select product_id, length(thumbnail), thumbnail_url " +
    "from products " +
    "where source = 'ozon' and thumbnail is not null " +
    "order by product_id " +
    "limit 1"
);

if (q.eof())
    throw "В базе нет thumbnail для проверки";

var id = str.toString(q.field(0));
var blobSize = q.field(1);
var url = str.toString(q.field(2));
q.close();

var imageQuery = db.query();
imageQuery.open(
    "select thumbnail from products " +
    "where source = 'ozon' and product_id = ?",
    #[id]
);

var bytes = imageQuery.field(0);
imageQuery.close();

var reencoded = qt.imageToPng(bytes, 96, 96);
if (reencoded == null)
    throw "Сохранённый BLOB не декодируется";

var width = bytes[16] * 16777216 + bytes[17] * 65536 + bytes[18] * 256 + bytes[19];
var height = bytes[20] * 16777216 + bytes[21] * 65536 + bytes[22] * 256 + bytes[23];

print("id=\(id), blob=\(str.toString(blobSize)), PNG=\(str.toString(width))x\(str.toString(height))");
print("thumbnail_url=" + url);
db.disconnect();
return 0;
