
// ozon.prg — разбор страницы избранного Ozon через DOM.
//
// Класс Ozon переназначаем при каждой загрузке, поскольку структура
// страницы может изменяться. Для поиска карточек и определения избранного
// используем атрибуты DOM (div[data-index], svg path fill).
//
// Использование:
// var oz = loadModule("lib/ozon.prg");
// loadModule регистрирует экспортируемые функции глобально,
// поэтому после загрузки их можно вызывать напрямую.
//
// Контейнер карточки товара:
// <div data-index="N" class="tile-root ...">
//
// Маркер избранного:
// SVG-сердечко с path fill="#F8104B" (красный цвет).
//
// Цена:
// конечные (leaf) элементы span с текстом вида "5 212 ₽".
// Первый найденный элемент — цена со скидкой,
// второй — старая цена.

// URL страницы избранного.
var favoritesUrl = "https://www.ozon.ru/my/favorites";

// Максимальное количество шагов прокрутки страницы.
var defaultMaxScrollSteps = 40;

// Количество последовательных шагов без появления новых карточек,
// после которого прокрутка считается завершённой.
var defaultStopTrailing = 5;

// Количество карточек, извлекаемых за один запрос к DOM.
var defaultChunk = 12;

// Цвет SVG-сердечка, обозначающего товар в избранном.
var favHeartFill = "#F8104B";
var favoritesScanComplete = false;
var favoritesFoundIds = #[];
var favoritesRecommendationStart = -1;
var recommendationsMarkerText = "Подобрали для вас";
var recommendationsMarkerTextAlt = "Рекомендовано для вас";

// ---------- JS-пробы (нестабильные class-name не используем,
// ориентируемся на структуру DOM и атрибуты элементов) ----------

// JavaScript-выражение для получения количества карточек на странице.
var jsTileCount = "document.querySelectorAll('div[data-index]').length";

function jsRecommendationsStartProbe() {
    return "(function(){try{var tiles=document.querySelectorAll('div[data-index]');var marker=null;"
        + "var nodes=document.querySelectorAll('span,div');"
        + "for(var i=0;i<nodes.length;i++){var e=nodes[i];"
        + "if(e.children.length===0&&e.textContent&&(e.textContent.indexOf("
        + json.stringify(recommendationsMarkerText) + ")>=0||e.textContent.indexOf("
        + json.stringify(recommendationsMarkerTextAlt) + ")>=0)){marker=e;break;}}"
        + "if(marker===null)return -1;"
        + "for(var i=0;i<tiles.length;i++){"
        + "if((marker.compareDocumentPosition(tiles[i])&4)!==0)return i;}"
        + "return tiles.length;}catch(e){return -2;}})()";
}

// Извлекает данные о карточках указанного диапазона.
// Возвращает JSON вида:
// {total, end, from, cards:[{id,ti,hl,t,o,f,im}]}
//
// total — общее количество карточек на странице;
// end   — индекс начала блока рекомендаций;
// from  — индекс первой обрабатываемой карточки;
// id    — идентификатор товара;
// ti    — название товара;
// hl    — ссылка на товар;
// t     — текущая цена;
// o     — старая цена;
// f     — признак нахождения товара в избранном.
// im    — URL первого изображения внутри этой карточки.
// u     — признак кнопки «Похожие» при отсутствии цены.
function jsCardsProbe(from, count) {
    var a = str.toString(from);
    var b = str.toString(count);
    return "(function(){try{"
        + "var RUB=String.fromCharCode(8381);"
        + "var RED='" + favHeartFill + "';"
        + "var tiles=document.querySelectorAll('div[data-index]');"
        + "var total=tiles.length;"
        + "var out=[];var A=" + a + ";var B=A+" + b + ";if(B>total)B=total;"
        + "for(var i=A;i<B;i++){"
        + "var c=tiles[i];"
        + "var im='';var bestImageScore=0;var imgs=c.querySelectorAll('img');"
        + "for(var z=0;z<imgs.length;z++){var el=imgs[z];var candidates=[];"
        + "var src=el.getAttribute('src')||el.getAttribute('data-src')||'';if(src)candidates.push(src);"
        + "var ss=el.getAttribute('srcset')||'';if(ss){var sa=ss.split(',');for(var si=0;si<sa.length;si++){var su=sa[si].trim().split(/\\s+/)[0];if(su)candidates.push(su);}}"
        + "if(candidates.length===0&&el.currentSrc)candidates.push(el.currentSrc);"
        + "for(var ci=0;ci<candidates.length;ci++){var cand=candidates[ci];if(cand.indexOf('//')===0)cand='https:'+cand;"
        + "var clean=cand.split('?')[0].split('#')[0];var score=0;"
        + "var mainOzon=clean.indexOf('https://ir')===0&&clean.indexOf('.ozone.ru/s3/multimedia-')>7;"
        + "if(mainOzon)score=1000;"
        + "var res=clean.match(/\\/wc(\\d+)\\//);if(res&&score>0)score+=parseInt(res[1],10);"
        + "if(score>bestImageScore){bestImageScore=score;im=clean;}}}"
        + "var as=c.querySelectorAll('a[href*=\"/product/\"]');"
        + "if(as.length===0)continue;"
        + "var href=as[0].getAttribute('href')||'';"
        + "var mm=href.match(/(\\d{6,13})(?=[\\/?]|$)/);"
        + "var id=mm?mm[1]:'';"
        + "var fav=0;"
        + "var ps=c.querySelectorAll('path');"
        + "for(var q=0;q<ps.length;q++){var f=ps[q].getAttribute('fill')||'';"
        + "if(f===RED||f===RED.substring(1)){fav=1;break;}}"
        + "if(!fav){for(var q=0;q<ps.length;q++){var st=getComputedStyle(ps[q]);var fl=st.fill||'';"
        + "if(fl==='rgb(248, 16, 75)'){fav=1;break;}}}"
        + "var prices=[];var sp=c.querySelectorAll('span');"
        + "for(var w=0;w<sp.length;w++){var el=sp[w];if(el.children.length)continue;"
        + "var tt=(el.textContent||'').trim();if(tt.length<1||tt.length>20)continue;"
        + "var cc=tt.replace(/\\s+/g,'');"
        + "if(cc.charAt(cc.length-1)!==RUB)continue;"
        + "var num=cc.substring(0,cc.length-1);"
        + "if(!/^[\\d]+([.,][\\d]{1,2})?$/.test(num))continue;"
        + "if(prices.indexOf(cc)>=0)continue;prices.push(cc);}"
        + "var txt=(c.innerText||'');var lines=txt.split('\\n');var title='';"
        + "for(var L=0;L<lines.length;L++){var ln=lines[L].trim();"
        + "if(ln.length>12&&ln.indexOf(RUB)<0&&ln.length>title.length)title=ln;}"
        + "var unavailable=0;"
        + "var actions=c.querySelectorAll('button,[role=button]');"
        + "for(var z=0;z<actions.length;z++){"
        + "var actionText=(actions[z].innerText||actions[z].textContent||actions[z].getAttribute('aria-label')||'')"
        + ".replace(/\\s+/g,' ').trim().toLowerCase();"
        + "if(actionText==='похожие'||actionText==='найти похожие'){unavailable=1;break;}}"
        + "out.push({id:id,di:i,ti:title,hl:href,t:prices.length?prices[0]:'',"
        + "o:prices.length>1?prices[1]:'',f:fav,im:im,u:unavailable});}"
        + "return JSON.stringify({total:total,from:A,cards:out});"
        + "}catch(e){return 'ERR:'+(e+'');}})()";
}

// Краткая диагностика источников изображений первых реальных карточек.
function jsImageDiag(count) {
    if (count == null) count = 4;
    return "(function(){try{var tiles=document.querySelectorAll('div[data-index]');var out=[];var n=Math.min(" + str.toString(count) + ",tiles.length);"
        + "for(var i=0;i<n;i++){var c=tiles[i];var card={index:i,imgs:[],backgrounds:[]};"
        + "var imgs=c.querySelectorAll('img');for(var j=0;j<imgs.length&&j<12;j++){var im=imgs[j],r=im.getBoundingClientRect();"
        + "card.imgs.push({src:im.getAttribute('src')||'',currentSrc:im.currentSrc||'',srcset:im.getAttribute('srcset')||'',alt:im.getAttribute('alt')||'',w:Math.round(r.width),h:Math.round(r.height)});}"
        + "var all=c.querySelectorAll('*');for(var k=0;k<all.length&&card.backgrounds.length<12;k++){var e=all[k],bg=getComputedStyle(e).backgroundImage;"
        + "if(bg&&bg.indexOf('url(')>=0){var r=e.getBoundingClientRect();if(r.width>40&&r.height>40)card.backgrounds.push({tag:e.tagName,bg:bg,w:Math.round(r.width),h:Math.round(r.height)});}}"
        + "out.push(card);}return JSON.stringify(out);}catch(e){return 'ERR:'+(e+'');}})()";
}

// ---------- Проверка доступности страницы ----------

// Определяет, отображается ли вместо страницы обычного содержимого
// антибот-проверка, страница ограничения доступа или challenge.
function isChallengeTitle(s) export {
    var low = str.lower(str.toString(coalesce(s, "")));
    if (str.pos(low, "antibot") >= 0) return true;
    if (str.pos(low, "challenge") >= 0) return true;
    if (str.pos(low, "нет со") >= 0) return true;
    if (str.pos(low, "доступ") >= 0) return true;
    if (str.pos(low, "похоже") >= 0) return true;
    return false;
}

// ---------- Функции управления браузером ----------

// Возвращает количество карточек на странице.
function favCount(page) export {
    if (page == null) return -1;
    var v = evalStr(page, jsTileCount);
    if (v == null) return -1;
    return str.toInt(str.toString(v));
}

// Проверяет именно избранное, а не карточки рекомендаций ниже списка.
// Возвращает число товаров до блока рекомендаций либо -1,
// если список избранного ещё не подтверждён.
function favAuthState(page) export {
    if (page == null) return -1;

    var marker = json.stringify(recommendationsMarkerText);
    var script = "(function(){try{"
        + "var title=(document.title||'').toLowerCase();"
        + "if(title.indexOf('antibot')>=0||title.indexOf('challenge')>=0)return -1;"
        + "var tiles=document.querySelectorAll('div[data-index]');"
        + "var marker=null;var nodes=document.querySelectorAll('span,div');"
        + "for(var i=0;i<nodes.length;i++){var e=nodes[i];"
        + "if(e.children.length===0&&e.textContent&&(e.textContent.indexOf(" + marker + ")>=0||"
        + "e.textContent.indexOf(" + json.stringify(recommendationsMarkerTextAlt) + ")>=0)){"
        + "marker=e;break;}}"
        + "var favorites=0;"
        + "if(marker!==null){for(var j=0;j<tiles.length;j++){"
        + "if((marker.compareDocumentPosition(tiles[j])&4)!==0)break;favorites++;}}"
        + "if(favorites>0)return favorites;return -1;"
        + "}catch(e){return -1;}})()";

    var result = evalStr(page, script);
    if (result == null) return -1;
    return str.toInt(str.toString(result));
}

// Прокручивает страницу до конца, чтобы подгрузить все карточки.
// Рекомендации отфильтровываются позже по признаку избранного.
function favScroll(page, maxSteps, stopTrailing) export {
    if (maxSteps == null) maxSteps = defaultMaxScrollSteps;
    if (stopTrailing == null) stopTrailing = defaultStopTrailing;
    if (page == null)
        return #{"count": 0, "complete": false};

    page.evaluate("window.scrollTo(0, 0)");
    system.sleep(0.4);

    var started = system.gettickcount();
    var prev = favCount(page);
    var scanStartedSuccessfully = (prev >= 0);
    print("Начало полной прокрутки: карточек=\(str.toString(prev))");

    var step = 0;
    var stable = 0;
    var atBottom = 0;
    var scanFailed = false;

    while (step < maxSteps) {
        page.evaluate("window.scrollBy(0, document.documentElement.clientHeight)");
        system.sleep(1.0);

        var n = favCount(page);

        if (n < 0) {
            scanFailed = true;
            break;
        }

        if (n == prev) stable++;
        else stable = 0;

        prev = n;
        step++;

        var bottomResult = evalStr(
            page,
            "window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 50 ? 1 : 0"
        );

        if (bottomResult == null or str.pos(str.toString(bottomResult), "ERR:") == 0) {
            scanFailed = true;
            break;
        }

        atBottom = str.toInt(str.toString(bottomResult));

        if (step % 5 == 0)
            print("Прокрутка, шаг \(str.toString(step)): карточек=\(str.toString(n))");

        if (atBottom == 1 and stable >= stopTrailing)
            break;
    }

    var total = favCount(page);
    if (total < 0)
        scanStartedSuccessfully = false;

    print(
        "Полная прокрутка завершена: шагов=" + str.toString(step) +
        ", карточек в DOM=" + str.toString(total) +
        ", время=" + str.toString((system.gettickcount() - started) / 1000.0) + " сек."
    );

    var scanComplete = scanStartedSuccessfully and !scanFailed and
        step < maxSteps and atBottom == 1 and stable >= stopTrailing;

    return #{"count": total, "complete": scanComplete};
}

// Извлекает карточки избранного из DOM порциями и возвращает
// массив объектов, полученных из JSON.
function favCollect(page, total, chunk) export {
    if (chunk == null) chunk = defaultChunk;
    if (page == null) return #[];
    if (total <= 0) return #[];
    var out = #[];
    var from = 0;
    var guard = 0;
    while (from < total and guard < 200) {
        var js = jsCardsProbe(from, chunk);
        var raw = evalStr(page, js);
        if (raw == null) {
            var perr = coalesce(page.lastError, "неизвестная ошибка");
            print("Не удалось получить карточки начиная с позиции \(str.toString(from)): \(perr)");
            break;
        }
        var st = str.toString(raw);
        if (str.pos(st, "ERR:") == 0) {
            print("Ошибка JavaScript при получении карточек: \(str.sub(st, 0, 300))");
            break;
        }
        var parsed = null;
        try { parsed = json.parse(st); } catch (e) { parsed = null; }
        if (parsed == null) {
            print("Не удалось разобрать ответ со списком карточек: \(str.sub(st, 0, 300))");
            break;
        }
        var cards = parsed.get("cards");
        var returnedTotal = str.toInt(str.toString(coalesce(parsed.get("total"), -1)));
        var returnedFrom = str.toInt(str.toString(coalesce(parsed.get("from"), -1)));

        if (returnedTotal != total or returnedFrom != from) {
            print("Ответ DOM не совпал с диапазоном запроса; сбор прерван.");
            break;
        }

        var got = 0;
        if (cards != null) {
            for (var cd : cards) {
                out.push(cd);
                got++;
            }
        }
        print("Карточки \(str.toString(from))–\(str.toString(from + chunk)): получено=\(str.toString(got)), всего=\(str.toString(total))");

        if (got != chunk and from + got < total) {
            print("Получена неполная порция карточек; сбор прерван.");
            break;
        }

        if (got == 0)
            break;

        from = from + chunk;
        guard++;
    }

    if (from < total)
        print("Сбор карточек завершён неполно: обработано \(str.toString(out.size())) из \(str.toString(total))");

    return out;
}

// Преобразует JSON-объект карточки в запись товара.
function cardProduct(cd) export {
    if (cd == null) return null;
    if (!cd.istuple()) return null;

    var id = normalizeId(cd.get("id"));
    if (id == "") return null;

    var pr = normalizePrice(cd.get("t"));
    var unavailable = (cd.get("u") == 1);
    if (pr == null and !unavailable) return null;

    var old = normalizePrice(cd.get("o"));
    if (old == pr) old = null;

    var f = 0;
    var fv = cd.get("f");
    if (fv != null) f = str.toInt(str.toString(fv));

    var title = cleanTitle(cd.get("ti"));
    var href = str.toString(coalesce(cd.get("hl"), ""));
    var qq = str.pos(href, "?");
    if (qq > 0) href = str.left(href, qq);

    var link = normalizeLink(href);
    var image = str.toString(coalesce(cd.get("im"), ""));
    var status = unavailable ? "out_of_stock" : "ok";

    var domIndexText = str.toString(coalesce(cd.get("di"), "-1"));
    var domIndex = str.toInt(domIndexText);

    return #{
        "id": id,
        "dom_index": domIndex,
        "title": title,
        "price": pr,
        "oldPrice": old,
        "fav": f,
        "link": link,
        "image": image,
        "status": status,
        "currency": "RUB"
    };
}

// Полный цикл обработки избранного:
// прокрутка страницы, извлечение карточек, преобразование записей,
// фильтрация по признаку избранного и удаление дубликатов.
function favProducts(page, maxSteps, stopTrailing, chunk, includeRecommendations) export {
    if (page == null)
        return #[];

    var scrollResult = favScroll(page, maxSteps, stopTrailing);
    var totalText = str.toString(coalesce(scrollResult.get("count"), "0"));
    var total = str.toInt(totalText);
    var completeText = str.toString(coalesce(scrollResult.get("complete"), "false"));
    favoritesScanComplete = (completeText == "true");
    favoritesFoundIds = #[];
    var recommendationProbe = evalStr(page, jsRecommendationsStartProbe());
    var recommendationProbeText = str.toString(coalesce(recommendationProbe, "-2"));
    favoritesRecommendationStart = str.toInt(recommendationProbeText);

    if (favoritesRecommendationStart < 0)
    {
        favoritesScanComplete = false;
        print("Не найден надёжный маркер начала рекомендаций; членство избранного не будет обновляться.");
    }

    var raw = favCollect(page, total, chunk);
    var rawCount = str.toInt(str.toString(raw.size()));

    if (rawCount != total)
        favoritesScanComplete = false;

    print("Получено карточек для обработки: \(str.toString(raw.size()))");

    if (includeRecommendations == null)
        includeRecommendations = false;

    var out = #[];
    var noheart = 0;
    var badid = 0;
    var nopriceN = 0;
    var unavailableN = 0;
    var nopriceIds = "";

    for (var cd : raw)
    {
        var rawDomIndex = str.toInt(str.toString(coalesce(cd.get("di"), "-1")));
        var rawIsRecommendation = favoritesRecommendationStart >= 0 and
            rawDomIndex >= favoritesRecommendationStart;
        var pr = cardProduct(cd);

        if (pr == null)
        {
            if (rawIsRecommendation)
                continue;

            var cid = str.toString(coalesce(cd.get("id"), ""));
            var hasId = (normalizeId(cid) != "");
            var hasPrice = (normalizePrice(cd.get("t")) != null);
            if (hasId and !hasPrice)
            {
                nopriceN++;
                if (nopriceN <= 6)
                    nopriceIds = nopriceIds + " " + cid;
            }
            else
            {
                badid++;
            }

            favoritesScanComplete = false;

            continue;
        }

        var f = pr.get("fav");
        var fi = 0;
        if (f != null)
            fi = str.toInt(str.toString(f));

        var hasFavoriteMark = (fi != 0);
        var trackedState = trackedProductForFavoriteScan(pr.get("id"));
        var domIndexText = str.toString(coalesce(pr.get("dom_index"), "-1"));
        var domIndex = str.toInt(domIndexText);
        var isRecommendation = favoritesRecommendationStart >= 0 and
            domIndex >= favoritesRecommendationStart;

        if (!isRecommendation)
        {
            if (hasFavoriteMark)
            {
                var seenFavorite = false;

                for (var foundId : favoritesFoundIds)
                {
                    if (str.toString(foundId) == str.toString(pr.get("id")))
                        seenFavorite = true;
                }

                if (!seenFavorite)
                    favoritesFoundIds.push(str.toString(pr.get("id")));

                var productUrl = str.toString(coalesce(pr.get("link"), ""));
                if (productUrl != "")
                    pr.set("favorite_link", productUrl);

                pr.set("favorite_state", "in_favorites");
            }
            else
            {
                noheart++;
                favoritesScanComplete = false;
            }
        }

        if (isRecommendation)
        {
            if (includeRecommendations and trackedState != null and
                trackedState.get("enabled") == true)
            {
                pr.set("tracking_enabled", true);
                out.push(pr);
            }

            continue;
        }

        if (!hasFavoriteMark)
            continue;

        if (trackedState != null and trackedState.get("enabled") != true)
            continue;

        if (str.toString(coalesce(pr.get("status"), "")) == "out_of_stock")
            unavailableN++;

        out.push(pr);
    }

    if (badid > 0 or nopriceN > 0)
        favoritesScanComplete = false;

    print("Полное сканирование DOM: \(str.toString(favoritesScanComplete))");

    print(
        "Фильтр избранного: оставлено=" + str.toString(out.size()) +
        ", нет в наличии=" + str.toString(unavailableN) +
        ", без отметки избранного=" + str.toString(noheart) +
        ", без цены=" + str.toString(nopriceN) +
        ", некорректных=" + str.toString(badid)
    );

    if (nopriceN > 0)
        print("Товары без цены (ID):" + nopriceIds);

    return dedupe(out);
}

function favoriteScanWasComplete() export {
    return favoritesScanComplete;
}

function favoriteScanIds() export {
    return favoritesFoundIds;
}

// ---------- Вспомогательные функции ----------

// Возвращает строку, содержащую только цифры из исходного значения.
function onlyDigits(s) export {
    var res = "";
    var n = str.len(s);
    for (var i = 0; i < n; i++) {
        var cp = s.codepointat(i);
        if (cp >= 48 and cp <= 57) res = res + str.sub(s, i, 1);
    }
    return res;
}

// Преобразует цену в числовое значение.
// Поддерживаемые варианты:
// "12 345 ₽", "12 345.67", 12345.
// Удаляет разделители разрядов и обозначение валюты,
// заменяет десятичную запятую точкой.
function normalizePrice(v) export {
    if (v == null) return null;
    if (v.isnumber()) return v;
    if (!v.isstring()) return null;
    var s = str.toString(v);
    s = str.replace(s, "\u2009", "");
    s = str.replace(s, "\u00A0", "");
    s = str.replace(s, "\u202F", "");
    s = str.replace(s, " ", "");
    s = str.replace(s, "₽", "");
    s = str.replace(s, "руб.", "");
    s = str.replace(s, ",", ".");
    s = str.trim(s);
    var out = "";
    var n = str.len(s);
    for (var i = 0; i < n; i++) {
        var ch = str.sub(s, i, 1);
        var cp = ch.codepointat(0);
        var ok = (cp >= 48 and cp <= 57);
        ok = (ok or cp == 46);
        if (ok) out = out + ch;
    }
    if (out == "" or out == ".") return null;
    var d = str.toDouble(out);
    if (d == null or d <= 0) return null;
    return d;
}

// Очищает название товара: удаляет лишние пробелы
// и переносы строк, ограничивает длину 140 символами.
function cleanTitle(v) export {
    if (v == null) return "";
    var t = str.trim(str.toString(v));
    t = str.replace(t, "\n", " ");
    if (str.len(t) > 140) t = str.sub(t, 0, 140);
    return str.trim(t);
}

// Проверяет и нормализует идентификатор товара.
// Допускаются только цифровые строки длиной от 4 до 13 символов.
function normalizeId(v) export {
    if (v == null) return "";
    var s = str.trim(str.toString(v));
    var n = str.len(s);
    if (n < 4 or n > 13) return "";
    if (onlyDigits(s) == s) return s;
    return "";
}

// Нормализует ссылку на карточку товара:
// относительные URL преобразует в абсолютные,
// добавляя домен Ozon.
function normalizeLink(link) export {
    var l = str.trim(str.toString(coalesce(link, "")));
    if (l == "") return "";
    if (str.startswith(l, "http")) return l;
    if (str.startswith(l, "/")) return "https://www.ozon.ru" + l;
    return l;
}

// Извлекает идентификатор товара из ссылки вида:
// /product/<slug>-<digits>/
// Возвращает пустую строку, если идентификатор определить не удалось.
function idFromLink(link) export {
    if (link == null or link == "") return "";
    var p = str.pos(link, "/product/");
    if (p < 0) return "";
    var rest = str.sub(link, p + 9);
    var q = str.findany(rest, "?");
    if (q > 0) rest = str.left(rest, q);
    var tailStart = str.rpos(rest, "-");
    var tail = "";
    if (tailStart >= 0) tail = str.sub(rest, tailStart + 1);
    else tail = rest;
    tail = onlyDigits(tail);
    var n = str.len(tail);
    if (n >= 4 and n <= 13) return tail;
    return "";
}

// Удаляет дубликаты товаров по идентификатору.
// Для отслеживания уже обработанных ID используется строка seen,
// а не словарь. Результат сохраняет исходный порядок записей.
function dedupe(products) export {
    var src = (products == null) ? #[] : products;
    var seen = "|";
    var out = #[];
    for (var pr : src) {
        var pid = pr.get("id");
        if (pid == null) continue;
        var key = "|" + str.toString(coalesce(pid, "")) + "|";
        if (key == "||") continue;
        if (str.pos(seen, key) >= 0) continue;
        seen = seen + key;
        out.push(pr);
    }
    return out;
}
