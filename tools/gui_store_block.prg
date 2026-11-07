// ============================================================
// Переключение магазина (блок вставляется мигратором update_gui_stores.prg)
// ============================================================

function productRowsSql(source)
{
    var sq = str.quoted(source);

    return "select p.product_id, p.name, coalesce(p.brand, '') as brand, " +
        "(select pp.price from price_points pp " +
        "where pp.source = p.source and pp.product_id = p.product_id " +
        "order by pp.captured_at desc, pp.id desc limit 1) as current_price, " +
        "case when p.status = 'out_of_stock' then 'Нет в наличии' " +
        "when coalesce(p.tracking_enabled, 1) = 0 then 'Не отслеживается' " +
        "when p.favorite_state = 'not_in_favorites' then 'Убрано из избранного' " +
        "else coalesce(p.status, '') end as status " +
        "from products p where p.source = " + sq + " " +
        "order by p.name collate nocase";
}

function historyRowsSql(source)
{
    var sq = str.quoted(source);

    return "select pp.captured_at, p.name, " +
        "case when pp.price = cast(pp.price as integer) " +
        "then replace(printf('%,d', cast(pp.price as integer)), ',', ' ') " +
        "else replace(replace(printf('%,.2f', pp.price), ',', ' '), '.', ',') end as price, " +
        "(select case when prev.price = cast(prev.price as integer) " +
        "then replace(printf('%,d', cast(prev.price as integer)), ',', ' ') " +
        "else replace(replace(printf('%,.2f', prev.price), ',', ' '), '.', ',') end " +
        "from price_points prev " +
        "where prev.source = pp.source and prev.product_id = pp.product_id " +
        "and (prev.captured_at < pp.captured_at " +
        "or (prev.captured_at = pp.captured_at and prev.id < pp.id)) " +
        "order by prev.captured_at desc, prev.id desc limit 1) as previous_price, pp.currency " +
        "from price_points pp " +
        "join products p on p.source = pp.source and p.product_id = pp.product_id " +
        "where pp.source = " + sq + " " +
        "order by pp.captured_at desc, pp.id desc limit 40";
}

// Отображаемое имя магазина (список в комбо, статус-строка).
function storeLabel(source)
{
    var label = coalesce(storeLabels[source], "");
    if (label == "") label = str.toString(coalesce(source, ""));
    return label;
}

// Заголовок блока товаров для магазина.
function storeTitle(source)
{
    var title = coalesce(storeTitles[source], "");
    if (title == "") title = str.upper(str.toString(coalesce(source, "")));
    return title;
}

function applyStore(source)
{
    if (source == currentSource)
        return;

    // Освобождаем запросы гридов до отключения текущей базы.
    form.productsGrid.close();
    form.historyGrid.close();

    db.disconnect();
    db.connect(db.QSQLITE, storeDb[source]);

    if (!db.active)
    {
        form.statusLabel.text = "Не удалось подключиться к базе: " + storeDb[source];
        return;
    }

    currentSource = source;

    form.productsGrid.sql = productRowsSql(currentSource);
    form.historyGrid.sql = historyRowsSql(currentSource);

    var productsOpened = form.productsGrid.open();
    var historyOpened = form.historyGrid.open();

    if (!productsOpened or !historyOpened)
    {
        form.statusLabel.text = "Не удалось обновить таблицы для магазина: "
            + storeLabel(source);
        return;
    }

    // Явно перечитываем модели после смены SQL и соединения.
    form.productsGrid.refresh();
    form.historyGrid.refresh();

    form.storeCombo.currentIndex = storeIndex[currentSource];
    form.productsTitle.text = "ИЗБРАННЫЕ ТОВАРЫ • " + storeTitle(currentSource);
    form.card.text = "Выберите товар в таблице слева, чтобы увидеть карточку.";
    form.thumbLabel.text = "Нет фото";
    form.chart.text = "";
    form.statusLabel.text = "Магазин: " + storeLabel(currentSource);
}

// Обработчик выбора магазина (подключён через events виджета storeCombo).
function storeCombo_currentIndexChanged(Sender, index)
{
    var source = "ozon";

    if (index != null and index >= 0 and index < storeSources.size())
        source = str.toString(storeSources[index]);

    applyStore(source);
}

// Наполнение переключателя магазинов при старте формы.
form.storeCombo.clear();

for (var si = 0; si < storeSources.size(); si++)
    form.storeCombo.addItem(storeLabel(storeSources[si]));

form.storeCombo.currentIndex = storeIndex[currentSource];
form.productsTitle.text = "ИЗБРАННЫЕ ТОВАРЫ • " + storeTitle(currentSource);
form.statusLabel.text = "Магазин: " + storeLabel(currentSource);
