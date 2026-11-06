// Шаг 2. Сканирование избранного Ozon и запись цен в SQLite (для крона).
// Запуск из корня проекта: bin\qodeqt.exe ozon_scan.prg
// Цены пишутся в price_points только если изменились относительно последней записи.
// loadModule регистрирует export-функции модулей глобально — вызываем напрямую.

var projectDir = file.dirname(file.absolute(system.getcommandline().args[0]));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/config.prg");
loadModule("lib/cdp.prg");
loadModule("lib/dbstore.prg");
loadModule("lib/ozon.prg");

var thumbnailHttp = HttpClient();
try { thumbnailHttp.setTimeout(12000); } catch (e) { }
var thumbnailDiagCount = 0;

var cfg = loadConfig("");
var runId = 0;

function shortName(s) {
    if (s == null) return "";
    var t = str.trim(str.toString(s));
    if (str.len(t) > 48) t = str.sub(t, 0, 48) + "...";
    return t;
}

// Скачивает только URL CDN Ozon, проверенный DOM-парсером, и сохраняет PNG 96x96.
// Сеть/декодирование необязательны для ценового сканирования: при ошибке продолжаем.
function captureThumbnail(pr) {
    if (pr == null) return false;
    var id = str.toString(coalesce(pr.get("id"), ""));
    var url = str.toString(coalesce(pr.get("image"), ""));
    var cacheKey = url + "|png96";
    if (hasThumbnail(id, cacheKey)) return false;
    if (url == "") return thumbnailFailure(id, "URL изображения не найден в DOM");
    var validCdn = false;
    if (str.startswith(url, "https://ir") and str.pos(url, ".ozone.ru/s3/multimedia-") > 0) validCdn = true;
    if (str.startswith(url, "https://cdn") and str.pos(url, ".ozonusercontent.com/s3/") > 0) validCdn = true;
    if (!validCdn) return thumbnailFailure(id, "URL вне разрешённых CDN Ozon");
    try {
        thumbnailHttp.clearHeaders();
        thumbnailHttp.setHeader("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8");
        if (!thumbnailHttp.get(url)) return thumbnailFailure(id, "GET изображения завершился ошибкой");
        if (thumbnailHttp.status() != 200) return thumbnailFailure(id, "HTTP \(str.toString(thumbnailHttp.status()))");
        var mime = str.lower(str.toString(coalesce(thumbnailHttp.getHeader("Content-Type"), "")));
        if (str.pos(mime, "image/") != 0) return thumbnailFailure(id, "ответ не image/*");
        var bytes = thumbnailHttp.getResponseBytes();
        if (bytes == null or bytes.size() == 0) return thumbnailFailure(id, "пустое тело ответа");
        if (bytes.size() > 8388608) return thumbnailFailure(id, "ответ превышает лимит 8 МиБ");
        var png = qt.imageToPng(bytes, 96, 96);
        if (png == null or png.size() == 0) return thumbnailFailure(id, "Qt не смог декодировать изображение");
        var saved = saveThumbnailIfChanged(id, cacheKey, png);
        if (saved) print("    Миниатюра сохранена (PNG 96x96)");
        return saved;
    } catch (e) {
        thumbnailFailure(id, "исключение при обработке");
        return false;
    }
}

function thumbnailFailure(id, reason) {
    if (thumbnailDiagCount < 12) {
        print("    [миниатюра \(id)] \(reason)");
        thumbnailDiagCount++;
    }
    return false;
}

function productsMissingThumbnail(limit) {
    if (limit == null)
        limit = 20;

    var q = db.query();
    q.open(
        "select product_id, best_url, coalesce(name, '') " +
        "from products " +
        "where source = 'ozon' and thumbnail is null " +
        "and coalesce(best_url, '') <> '' " +
        "order by updated_at desc " +
        "limit " + str.toString(limit)
    );

    var out = #[];

    while (!q.eof()) {
        out.push(#{
            "id": str.toString(q.field(0)),
            "url": str.toString(q.field(1)),
            "name": str.toString(q.field(2))
        });
        q.next();
    }

    q.close();
    return out;
}

function productPageImageProbe() {
    return "(function(){try{"
        + "var best='';var bestArea=0;var bestSize=0;"
        + "var imgs=document.querySelectorAll('img');"
        + "for(var i=0;i<imgs.length;i++){"
        + "var el=imgs[i];var r=el.getBoundingClientRect();"
        + "var area=Math.max(el.naturalWidth||0,Math.round(r.width))*"
        + "Math.max(el.naturalHeight||0,Math.round(r.height));"
        + "var candidates=[];"
        + "var src=el.getAttribute('src')||el.getAttribute('data-src')||'';"
        + "if(src)candidates.push(src);"
        + "if(el.currentSrc)candidates.push(el.currentSrc);"
        + "var srcset=el.getAttribute('srcset')||'';"
        + "if(srcset){var parts=srcset.split(',');"
        + "for(var j=0;j<parts.length;j++){var u=parts[j].trim().split(/\\s+/)[0];"
        + "if(u)candidates.push(u);}}"
        + "for(var j=0;j<candidates.length;j++){var u=candidates[j];"
        + "if(u.indexOf('//')===0)u='https:'+u;"
        + "if(u.indexOf('https://ir')!==0||u.indexOf('.ozone.ru/s3/multimedia-')<0)continue;"
        + "u=u.split('?')[0].split('#')[0];"
        + "var m=u.match(/\\/wc(\\d+)\\//);var size=m?parseInt(m[1],10):0;"
        + "if(area>bestArea||(area===bestArea&&size>bestSize)){"
        + "best=u;bestArea=area;bestSize=size;}}}"
        + "if(!best){var meta=document.querySelector('meta[property=\"og:image\"]');"
        + "if(meta){var u=meta.getAttribute('content')||'';"
        + "if(u.indexOf('//')===0)u='https:'+u;"
        + "if(u.indexOf('https://ir')===0&&u.indexOf('.ozone.ru/s3/multimedia-')>0)best=u.split('?')[0];}}"
        + "return JSON.stringify({url:location.href,title:document.title,image:best,"
        + "imageCount:imgs.length,bestArea:bestArea});"
        + "}catch(e){return 'ERR:'+(e+'');}})()";
}

function recoverProductThumbnails(page, limit) {
    var missing = productsMissingThumbnail(limit);
    var recovered = 0;

    print("Проверка карточек без миниатюры по сохранённым ссылкам: \(str.toString(missing.size()))");

    for (var product : missing) {
        var id = product.get("id");
        var url = product.get("url");

        var productName = str.toString(product.get("name"));
        print("  Проверка фото товара \(id): \(shortName(productName))");

        if (!navigate(page, url)) {
            print("    Не удалось открыть карточку товара");
            continue;
        }

        var ready = false;
        var deadline = system.gettickcount() + 20000;

        while (system.gettickcount() < deadline) {
            var state = evalStr(page, "document.readyState");
            if (state == "complete" or state == "interactive") {
                ready = true;
                break;
            }
            system.sleep(0.5);
        }

        if (!ready) {
            print("    Страница не загрузилась вовремя");
            continue;
        }

        system.sleep(1.5);

        var raw = evalStr(page, productPageImageProbe());
        if (raw == null or raw == "") {
            print("    Не удалось прочитать изображения карточки");
            continue;
        }

        var info = null;
        try {
            info = json.parse(str.toString(raw));
        } catch (parseError) {
            info = null;
        }

        if (info == null) {
            print("    Ответ диагностики изображения некорректен");
            continue;
        }

        var imageUrl = str.toString(coalesce(info.get("image"), ""));
        if (imageUrl == "") {
            print("    Основная фотография в карточке не найдена");
            continue;
        }

        var productData = #{"id": id, "image": imageUrl};
        if (captureThumbnail(productData)) {
            recovered++;
            print("    Фото найдено на странице товара: " + imageUrl);
        }
    }

    print("Восстановлено миниатюр по страницам товаров: \(str.toString(recovered))");
    return recovered;
}

function main() {
    // Ozon антиботом блокирует headless-браузеры — работаем с окном
    var headless = cfgGet(cfg, "browser.headless", false);
    var port = cfgGet(cfg, "browser.debugPort", 9222);
    var profile = cfgGet(cfg, "browser.profileDir", "private_data/browser_profile");
    var favUrl = cfgGet(cfg, "ozon.favoritesUrl", "https://www.ozon.ru/my/favorites");
    var waitLoginSec = cfgGet(cfg, "ozon.waitLoginSeconds", 300);
    var pageWaitSec = cfgGet(cfg, "ozon.pageWaitSeconds", 25);
    var dbPath = cfgGet(cfg, "db.path", "private_data/ozon/ozon.sqlite");

    cdpSetup(port, profile, cfgGet(cfg, "browser.execPath", ""));
    print("Подключаемся к базе...");
    storeConnect(dbPath);
    markStaleRuns();
    runId = beginRun("ozon favorites");
    var tTotal = system.gettickcount();
    print("Шаг 1/6: закрываем прошлый браузер...");
    stopExisting();

    print("Шаг 2/6: запуск браузера...");
    print((headless ? "Режим: headless (без окна)" : "Режим: с окном браузера"));
    var cookieFile = "private_data/ozon/ozon_cookies.json";
    var haveCookies = file.exists(cookieFile);
    if (haveCookies) {
        print("Куки есть — восстановлю сессию из " + cookieFile);
    } else {
        print("Файла куки нет — нужна авторизация: bin\qodeqt.exe ozon_auth.prg");
    }
    var startPage = haveCookies ? "about:blank" : favUrl;
    var proc = openBrowser(headless, startPage, cfgGet(cfg, "browser.proxy", ""));
    if (!waitForDevTools(port, 60)) {
        error("DevTools не поднялись за 60 сек. Проверьте config.json: browser.execPath");
        finishRun(runId, 0, 0, "error_devtools");
        closeBrowser(port);
        system.exit(1);
    }

    // дожидаемся первой вкладки
    var target = null;
    var tabDeadline = system.gettickcount() + 30000;
    while (system.gettickcount() < tabDeadline) {
        target = findTarget(port, "", null);
        if (target != null) break;
        system.sleep(1);
    }
    if (target == null) {
        error("Браузер не открыл ни одной вкладки");
        finishRun(runId, 0, 0, "no_tabs");
        closeBrowser(port);
        system.exit(3);
    }

    var page = attachToPage(target);
    if (page == null) {
        error("Не удалось подключиться к странице через DevTools");
        finishRun(runId, 0, 0, "no_cdp_page");
        closeBrowser(port);
        system.exit(3);
    }

    if (haveCookies) {
        print("Шаг 3/6: восстановление куки и переход к избранному...");
        var restored = restoreCookiesFromFile(page, cookieFile);
        if (restored == 0) {
            print("Куки не восстановились — продолжаю без них (может понадобиться ozon_auth.prg)");
        }
        navigate(page, favUrl);
        system.sleep(2);
        var np = reconnectFavorites(port, favUrl);
        if (np != null) {
            closeConnSafely(page);
            page = np;
        }
    } else {
        print("Шаг 3/6: дожидаемся страницы Ozon (лимит \(str.toString(waitLoginSec)) сек)...");
    }

    // дожидаемся страницы избранного; сразу ловим сброс авторизации
    var deadline = system.gettickcount() + waitLoginSec * 1000;
    target = null;
    var lastLog = system.gettickcount();
    var needAuth = false;
    while (system.gettickcount() < deadline) {
        var t = findTarget(port, "ozon.ru", null);
        if (t != null) {
            var u = str.lower(coalesce(t.get("url"), ""));
            if (str.pos(u, "my/favorites") >= 0) {
                target = t;
                print("Страница избранного найдена: " + coalesce(t.get("url"), ""));
                break;
            }
            if (str.pos(u, "/login") >= 0) {
                needAuth = true;
                break;
            }
            if (haveCookies) {
                // проверим реальный адрес внутри вкладки (заголовок может ещё не смениться)
                var realUrl = currentPageLowerUrl(page);
                if (str.pos(realUrl, "my/favorites") >= 0) {
                    target = t;
                    print("Страница избранного найдена (по location.href): " + realUrl);
                    break;
                }
                if (str.pos(realUrl, "/login") >= 0) {
                    needAuth = true;
                    break;
                }
            }
            if (system.gettickcount() - lastLog > 10000) {
                lastLog = system.gettickcount();
                print("Ожидание избранного, текущий URL: " + coalesce(t.get("url"), ""));
            }
        }
        target = null;
        system.sleep(2);
    }
    if (needAuth) {
        error("Сессия сброшена — требуется вход на Ozon. Запустите: bin\qodeqt.exe ozon_auth.prg");
        finishRun(runId, 0, 0, "auth_required");
        closeConnSafely(page);
        closeBrowser(port);
        system.exit(2);
    }
    if (target == null) {
        error("Страница избранного не открылась — вероятно слетела авторизация. Запустите: bin\qodeqt.exe ozon_auth.prg");
        finishRun(runId, 0, 0, "auth_required");
        closeConnSafely(page);
        closeBrowser(port);
        system.exit(2);
    }

    if (!pageAlive(page)) {
        print("CDP: соединение с вкладкой потеряно — повторно подключаюсь к вкладке Ozon...");
        var rp = reconnectFavorites(port, favUrl);
        if (rp != null) {
            closeConnSafely(page);
            page = rp;
        }
    }

    print("Шаг 4/6: ожидаем загрузки избранного (с повторными попытками при проверке антибота)...");
    waitPageComplete(page, pageWaitSec);
    var tilesReady = -1;
    var ready = false;
    var tryNo = 0;
    var readyDeadline = system.gettickcount() + waitLoginSec * 1000;
    while (system.gettickcount() < readyDeadline) {
        tilesReady = favCount(page);
        if (tilesReady > 0) {
            ready = true;
            break;
        }
        tryNo++;
        var ttl = coalesce(pageTitle(page), "");
        var isChall = isChallengeTitle(ttl);
        // Временная страница-заглушка Ozon: «Похоже, нет соединений»
        // (fab_chlg / fab_nmk). Проверка таких страниц находится в isChallengeTitle().
        print("Ожидание карточек, попытка \(str.toString(tryNo)): карточек=\(str.toString(tilesReady)), заголовок=[\(ttl)]");
        if (!pageAlive(page)) {
            print("  CDP: соединение потеряно — повторно подключаюсь к вкладке...");
            page = reconnectFavorites(port, favUrl);
            continue;
        }
        if (isChall) {
            print("  Открыта проверочная страница Ozon — ожидаю 8 секунд...");
            system.sleep(8);
            var c2 = favCount(page);
            if (c2 > 0) {
                tilesReady = c2;
                ready = true;
                break;
            }
            page = refreshFavoritesForce(page, port, favUrl);
        } else {
            page = refreshFavoritesForce(page, port, favUrl);
        }
        system.sleep(3);
    }
    if (!ready) {
        var dl = dumpPageHtml(page, "private_data/ozon/fav_challenge_dump.html", 40000);
        error("Избранное не загрузилось (карточек: 0, размер дампа: \(str.toString(dl)) символов). Запустите ozon_auth.prg для повторной авторизации.");
        finishRun(runId, 0, 0, "auth_required");
        closeConnSafely(page);
        closeBrowser(port);
        system.exit(4);
    }
    print("Избранное загружено: карточек=\(str.toString(tilesReady))");

    print("Шаг 5/6: прокрутка страницы и разбор карточек...");
    var products = favProducts(page,
        cfgGet(cfg, "ozon.maxScrollSteps", 40),
        cfgGet(cfg, "ozon.stopTrailing", 5),
        cfgGet(cfg, "ozon.chunk", 12),
        true);

    if (products.empty()) {
        var dl2 = dumpPageHtml(page, "private_data/ozon/ozon_favorites_dump.html", 40000);
        error("Не удалось распознать карточки товаров (размер дампа: \(str.toString(dl2)) символов). Требуется проверить парсер.");
        finishRun(runId, 0, 0, "parse_fail");
        closeConnSafely(page);
        closeBrowser(port);
        system.exit(4);
    }

    var total = products.size();
    print("Найдено товаров: \(str.toString(total))");
    print("Шаг 6/6: запись в базу...");

    var changed = 0;
    var fresh = 0;
    var idx = 0;
    for (var pr : products) {
        idx++;
        var pid = pr.get("id");
        if (pid == "") continue;
        var title = pr.get("title");
        if (title == "") title = "Товар " + pid;
        var price = pr.get("price");

        var isFavorite = (pr.get("favorite_state") == "in_favorites");

        // Рекомендации не меняют цену, статус или описание товара;
        // используем их только как запасной источник миниатюры для уже учтённых ID.
        if (!isFavorite) {
            if (pr.get("tracking_enabled") == true and captureThumbnail(pr))
                print("    Миниатюра взята из карточки рекомендаций для id=" + pid);

            continue;
        }

        var before = getLastPrice(pid);
        upsertProduct(
            pid,
            title,
            pr.get("brand"),
            pr.get("link"),
            pr.get("status"),
            "in_favorites"
        );

        captureThumbnail(pr);

        if (price != null) {
            var rowPrefix = "  [\(str.toString(idx))/\(str.toString(total))] ";
            print(rowPrefix + shortName(title) + " id=" + pid + " цена=" + format("%.2f", price));
            var wrote = addPricePoint(pid, price, pr.get("oldPrice"), pr.get("currency"), pr.get("status"));
            if (wrote == 1) {
                changed++;
                if (before == null) {
                    fresh++;
                    var cur = pr.get("currency");
                    var titleS = shortName(title);
                    var priceS = format("%.2f", price);
                    print("[новый] \(titleS) — \(priceS) \(cur)");
                } else {
                    var titleS2 = shortName(title);
                    var beforeS = format("%.2f", before);
                    var priceS2 = format("%.2f", price);
                    print("[цена]  \(titleS2): \(beforeS) -> \(priceS2)");
                }
            }
        } else if (str.toString(coalesce(pr.get("status"), "")) == "out_of_stock") {
            print(
                "  [\(str.toString(idx))/\(str.toString(total))] " +
                shortName(title) + " id=" + pid + " — нет в наличии"
            );
        }
    }

    if (favoriteScanWasComplete()) {
        markFavoriteMembership(favoriteScanIds());
        print("Статусы избранного обновлены по полному сканированию.");
    } else {
        print("Сканирование было неполным: статусы избранного не менялись.");
    }

    recoverProductThumbnails(page, 20);

    finishRun(runId, total, changed, "ok");

    var saved = saveCookiesToFile(page, cookieFile);
    if (saved == 1) print("Куки обновлены.");
    else print("Не удалось обновить куки.");
    closeConnSafely(page);

    var snap = #{
        "at": datetime.strftime(datetime.now(), "%Y-%m-%d %H:%M:%S"),
        "items": products
    };
    file.mkdirrecursive("private_data/ozon");
    file.write("private_data/ozon/ozon_last_scan.json", json.stringify(snap, true), file.ENC_UTF8_BOM);

    print("Снапшот: private_data/ozon/ozon_last_scan.json");
    var elapsed = str.toString((system.gettickcount() - tTotal) / 1000.0);
    print("=== Итог: товаров \(str.toString(total)), новых точек цены \(str.toString(changed)) (из них новых товаров \(str.toString(fresh))), время \(elapsed) сек ===");
    print("Шаг 7/7: закрытие браузера...");
    closeBrowser(port);
}

function errText(e) {
    if (e != null) {
        if (e.istuple()) {
            if (e.has("message")) return e.message;
        }
    }
    return str.toString(e);
}

try {
    main();
} catch (e) {
    var msg = errText(e);
    var sql = "";
    if (e != null) {
        if (e.istuple()) {
            if (e.has("sql")) sql = " SQL: " + e.sql;
        }
    }
    error("Ошибка: " + msg + sql);
    if (runId > 0) {
        try { finishRun(runId, 0, 0, "error_exception"); } catch (e2) { }
    }
    system.exit(1);
}
return 0;
