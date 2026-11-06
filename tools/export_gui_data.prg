// Экспорт данных просмотра ScanMarket в JSON для GUI.
// База открывается только на чтение логически: выполняются только SELECT-запросы.
uses db;

var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;
loadModule("lib/config.prg");

var cfg = loadConfig("");
var dbFile = file.absolute(cfgGet(cfg, "db.path", "private_data/ozon/ozon.sqlite"));
var outFile = "private_data/scanmarket_view.json";

function nullText(v, fallback) {
    return v == null ? fallback : str.toString(v);
}

function main() {
    if (!file.exists(dbFile)) throw "База не найдена: " + dbFile;
    db.connect(db.QSQLITE, dbFile);
    if (!db.active) throw "Не удалось подключиться к SQLite: " + dbFile;

    var products = #[];
    var q = db.query();
    q.open("select source, product_id, coalesce(name, ''), coalesce(brand, ''), coalesce(best_url, ''), coalesce(status, '') from products where source = 'ozon' order by name collate nocase");
    while (!q.eof()) {
        var source = str.toString(q.field(0));
        var productId = str.toString(q.field(1));
        var points = #[];
        var p = db.query();
        p.open("select captured_at, price, old_price, currency, status from price_points where source = \(str.quoted(source)) and product_id = \(str.quoted(productId)) order by captured_at, id");
        while (!p.eof()) {
            points.push(#{
                "captured_at": nullText(p.field(0), ""),
                "price": p.field(1),
                "old_price": p.field(2),
                "currency": nullText(p.field(3), "RUB"),
                "status": nullText(p.field(4), "")
            });
            p.next();
        }
        p.close();
        products.push(#{
            "source": source,
            "product_id": productId,
            "name": str.toString(q.field(2)),
            "brand": str.toString(q.field(3)),
            "url": str.toString(q.field(4)),
            "status": str.toString(q.field(5)),
            "points": points
        });
        q.next();
    }
    q.close();
    file.mkdirrecursive(file.dirname(outFile));
    file.write(outFile, json.stringify(#{"exported_at": datetime.strftime(datetime.now(), "%Y-%m-%d %H:%M:%S"), "products": products}, true), file.ENC_UTF8_BOM);
    print("Экспортировано товаров: \(str.toString(products.size()))");
    print("Файл: " + file.absolute(outFile));
}

try {
    main();
} catch (e) {
    error("Ошибка экспорта GUI: \(str.toString(e))");
    system.exit(1);
}
return 0;
