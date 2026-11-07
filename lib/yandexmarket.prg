// yandexmarket.prg — разбор страницы избранного Яндекс Маркета через DOM.
//
// Структура карточек и waymarking могут меняться, поэтому ориентируемся
// на устойчивые атрибуты data-auto, а не на class-name:
//   - карточка товара: контейнер, содержащий title и цену/сердечко;
//   - название: span[data-auto="snippet-title"];
//   - ссылка на товар: a[data-auto="snippet-link"], href вида /card/<slug>/<id>;
//   - цена: [data-auto="snippet-price-current"] (текст вида "3 841 ₽");
//   - сердечко избранного: span[data-auto="wishlist-active"] внутри
//     button[data-auto="wishlist"] (в избранном — активное, в рекомендациях — нет);
//   - начало блока рекомендаций — заголовок «Достойны сердечка».
//
// Использование:
// var ym = loadModule("lib/yandexmarket.prg");
// loadModule регистрирует экспортируемые функции глобально,
// поэтому после загрузки их можно вызывать напрямую.

// URL страницы избранного.
var ymFavoritesUrl = "https://market.yandex.ru/my/wishlist";

// Максимальное количество шагов прокрутки страницы.
var ymDefaultMaxScrollSteps = 40;

// Количество последовательных шагов без появления новых карточек,
// после которого прокрутка считается завершённой.
var ymDefaultStopTrailing = 5;

// Количество карточек, извлекаемых за один запрос к DOM.
var ymDefaultChunk = 12;

// Маркер активного сердечка избранного (data-auto).
var ymHeartActive = "wishlist-active";

var ymScanComplete = false;
var ymFoundIds = #[];
var ymRecommendationStart = -1;
var ymRecommendationMarkers = #["Достойны сердечка", "Похожие товары", "Смотрите также"];

// Корневой контейнер страницы вишлиста: сам список или body.
var jsYmRootProbe = "(function(){"
    + "var r=document.querySelector('[data-auto=\"wishlistLayout\"]');"
    + "if(r)return r;"
    + "return document.body;})()";

// Находит корень карточки: ближайший предок названия, внутри которого есть
// цена либо сердечко. Для каждого data-auto="snippet-title" получаем одну карточку.
var jsYmTilesFn = "(function(root){"
    + "var titles=root.querySelectorAll('[data-auto=\"snippet-title\"]');"
    + "var seen=[];"
    + "for(var i=0;i<titles.length;i++){"
    + "var t=titles[i];var el=t;var card=null;"
    + "while(el&&el!==root&&el!==document.body){"
    + "el=el.parentElement;if(!el)break;if(el.nodeType!==1)continue;"
    + "var hasPrice=el.querySelector('[data-auto=\"snippet-price-current\"]');"
    + "var hasHeart=el.querySelector('[data-auto=\"wishlist-active\"],button[data-auto=\"wishlist\"]');"
    + "if(hasPrice||hasHeart){card=el;break;}"
    + "}"
    + "if(card&&seen.indexOf(card)<0)seen.push(card);}"
    + "var markers=root.querySelectorAll('h1,h2,h3');"
    + "var end=seen.length;"
    + "for(var m=0;m<markers.length;m++){"
    + "var mt=(markers[m].textContent||'').trim();"
    + "if(mt!=='Достойны сердечка')continue;"
    + "for(var j=0;j<seen.length;j++){"
    + "if((markers[m].compareDocumentPosition(seen[j])&4)!==0){end=j;break;}}"
    + "break;}"
    + "return seen.slice(0,end);})";
    + "return seen;})";

var jsYmCount = "(function(){"
    + "var root=" + jsYmRootProbe + ";"
    + "return " + jsYmTilesFn + "(root).length;})()";

// ---------- JS-пробы ----------

// Возвращает индекс первой карточки, начиная с которой идут рекомендации,
// или -1, если маркер не найден.
function jsYmRecommendationsStartProbe() {
    var markers = json.stringify(ymRecommendationMarkers);
    return "(function(){try{"
        + "var root=" + jsYmRootProbe + ";"
        + "var tiles=" + jsYmTilesFn + "(root);"
        + "var markers=" + markers + ";"
        + "var nodes=root.querySelectorAll('h1,h2,h3,span,div');"
        + "for(var i=0;i<nodes.length;i++){"
        + "var e=nodes[i];"
        + "if(e.children.length>3)continue;"
        + "var tx=(e.textContent||'').trim();"
        + "for(var m=0;m<markers.length;m++){"
        + "if(tx.indexOf(markers[m])>=0){"
        + "for(var j=0;j<tiles.length;j++){"
        + "if((e.compareDocumentPosition(tiles[j])&4)!==0)return j;}"
        + "return tiles.length;}}}"
        + "return -1;"
        + "}catch(e){return -2;}})()";
}

// Извлекает данные о карточках указанного диапазона.
// Возвращает JSON вида:
// {total, from, cards:[{id,di,ti,hl,t,o,f,im,u}]}
//
// id    — идентификатор товара (последний сегмент ссылки /card/<slug>/<id>);
// di    — индекс карточки в результатах поиска;
// ti    — название товара;
// hl    — ссылка на товар;
// t     — текущая цена;
// o     — старая цена (у Яндекса обычно отсутствует — пустая строка);
// f     — признак нахождения товара в избранном (активное сердечко);
// im    — URL первого изображения внутри карточки;
// u     — признак недоступности товара.
function jsYmCardsProbe(from, count) {
    var a = str.toString(from);
    var b = str.toString(count);
    return "(function(){try{"
        + "var RUB=String.fromCharCode(8381);"
        + "var root=" + jsYmRootProbe + ";"
        + "var tiles=" + jsYmTilesFn + "(root);"
        + "var total=tiles.length;"
        + "var out=[];var A=" + a + ";var B=A+" + b + ";if(B>total)B=total;"
        + "for(var i=A;i<B;i++){"
        + "var c=tiles[i];"
        + "var titleEl=c.querySelector('[data-auto=\"snippet-title\"]');"
        + "var title=titleEl?(titleEl.textContent||'').trim():'';"
        + "var href='';"
        + "var links=c.querySelectorAll('a[data-auto=\"snippet-link\"]');"
        + "for(var z=0;z<links.length;z++){var hh=links[z].getAttribute('href')||'';if(hh){href=hh;break;}}"
        + "if(href===''){var gl=c.querySelector('a[data-auto=\"galleryLink\"]');if(gl)href=gl.getAttribute('href')||'';}"
        + "var u=href.split('?')[0];"
        + "var mm=u.match(/\\/(\\d{5,14})\\/?$/);"
        + "var id=mm?mm[1]:'';"
        + "if(id==='')continue;"
        + "var fav=c.querySelector('[data-auto=\"wishlist-active\"]')?1:0;"
        + "var im='';var bestScore=0;var bestArea=0;"
        + "var imgs=c.querySelectorAll('img');"
        + "for(var q=0;q<imgs.length;q++){var el=imgs[q];var candidates=[];"
        + "var src=el.getAttribute('src')||el.getAttribute('data-src')||'';if(src)candidates.push(src);"
        + "if(el.currentSrc)candidates.push(el.currentSrc);"
        + "var ss=el.getAttribute('srcset')||'';if(ss){var ssa=ss.split(',');"
        + "for(var si=0;si<ssa.length;si++){var su=ssa[si].trim().split(/\\s+/)[0];if(su)candidates.push(su);}}"
        + "for(var ci=0;ci<candidates.length;ci++){var cand=candidates[ci];"
        + "if(cand.indexOf('//')===0)cand='https:'+cand;"
        + "var clean=cand.split('?')[0].split('#')[0];var score=0;var area=0;"
        + "if(clean.indexOf('avatars.mds.yandex.net')>0)score=1000;"
        + "if(clean.indexOf('market.yandex.ru')>0&&score===0)score=500;"
        + "var rr=el.getBoundingClientRect();"
        + "area=Math.max(el.naturalWidth||0,Math.round(rr.width))*Math.max(el.naturalHeight||0,Math.round(rr.height));"
        + "if(score>bestScore||(score===bestScore&&area>bestArea)){bestScore=score;bestArea=area;im=clean;}}}"
        + "var t='';var pe=c.querySelector('[data-auto=\"snippet-price-current\"]');"
        + "if(pe){var pt=(pe.textContent||'').trim();"
        + "var pn=pt.replace(/\\s+/g,'');"
        + "if(pn.length>=2&&pn.charAt(pn.length-1)===RUB)t=pt;}"
        + "if(t===''){var sp=c.querySelectorAll('span');"
        + "for(var w=0;w<sp.length;w++){var e2=sp[w];if(e2.children.length)continue;"
        + "var tt=(e2.textContent||'').trim();if(tt.length<1||tt.length>20)continue;"
        + "var cc=tt.replace(/\\s+/g,'');"
        + "if(cc.charAt(cc.length-1)!==RUB)continue;"
        + "var num=cc.substring(0,cc.length-1);"
        + "if(!/^[\\d]+([.,][\\d]{1,2})?$/.test(num))continue;"
        + "t=tt;break;}}"
        + "var txt=(c.innerText||'');var low=txt.toLowerCase();"
        + "var unavailable=0;"
        + "if(t===''){"
        + "if(low.indexOf('нет в наличии')>=0||low.indexOf('закончился')>=0"
        + "||low.indexOf('закончились')>=0||low.indexOf('недоступен')>=0||low.indexOf('уведомить')>=0)unavailable=1;}"
        + "out.push({id:id,di:i,ti:title,hl:href,t:t,o:'',f:fav,im:im,u:unavailable});}"
        + "return JSON.stringify({total:total,from:A,cards:out});"
        + "}catch(e){return 'ERR:'+(e+'');}})()";
}

// Краткая диагностика реальных карточек для уточнения селектора сердечка
// и структуры. Не записывает названия, цены, ссылки или содержимое профиля.
function jsYmDiagProbe() {
    return "(function(){try{"
        + "var root=" + jsYmRootProbe + ";"
        + "var titles=root.querySelectorAll('[data-auto=\"snippet-title\"]');"
        + "var cards=[];"
        + "for(var i=0;i<titles.length&&i<4;i++){var t=titles[i];var el=t;var card=null;"
        + "while(el&&el!==root&&el!==document.body){el=el.parentElement;if(!el)break;"
        + "if(el.querySelector('[data-auto=\"snippet-price-current\"]')||el.querySelector('[data-auto=\"wishlist-active\"]')){card=el;break;}}"
        + "if(!card)continue;"
        + "var item={attrs:{},controls:[]};"
        + "for(var a=0;a<card.attributes.length;a++){var at=card.attributes[a];"
        + "if(at.name==='class'||at.name.indexOf('data-')===0)item.attrs[at.name]=at.value;}"
        + "var els=card.querySelectorAll('[data-auto],button,svg,path');"
        + "for(var j=0;j<els.length&&j<40;j++){var e=els[j];var n={tag:e.tagName};"
        + "n.auto=e.getAttribute('data-auto')||'';"
        + "n.cls=(typeof e.className==='string'?e.className.slice(0,60):'');"
        + "item.controls.push(n);}"
        + "cards.push(item);}"
        + "return JSON.stringify({count:cards.length,cards:cards});"
        + "}catch(e){return 'ERR:'+(e+'');}})()";
}

// ---------- Проверка доступности страницы ----------

// Определяет, отображается ли вместо избранного антибот-проверка Яндекс
// Маркета («Подтвердите, что вы не робот», «Заметили подозрительную
// активность», «Доступ ограничен», капча) или страница входа.
function isYmChallengeTitle(s) export {
    var low = str.lower(str.toString(coalesce(s, "")));
    if (str.pos(low, "подтвердите") >= 0) return true;
    if (str.pos(low, "не робот") >= 0) return true;
    if (str.pos(low, "подозрительную активность") >= 0) return true;
    if (str.pos(low, "доступ ограничен") >= 0) return true;
    if (str.pos(low, "captcha") >= 0) return true;
    if (str.pos(low, "checking your browser") >= 0) return true;
    if (str.pos(low, "access denied") >= 0) return true;
    if (str.pos(low, "passport") >= 0) return true;
    if (str.pos(low, "войдите") >= 0) return true;
    if (str.pos(low, "вход") >= 0) return true;
    return false;
}

// ---------- Функции управления браузером ----------

// Возвращает количество карточек на странице.
function ymFavCount(page) export {
    if (page == null) return -1;
    var v = evalStr(page, jsYmCount);
    if (v == null) return -1;
    return str.toInt(str.toString(v));
}

// Количество активных сердечек — это число товаров в избранном.
// Рекомендации отображаются неактивным сердечком и не учитываются.
function ymFavActiveCount(page) export {
    if (page == null) return -1;
    var v = evalStr(
        page,
        "(function(){return document.querySelectorAll('[data-auto=\"wishlist-active\"]').length;})()"
    );
    if (v == null) return -1;
    return str.toInt(str.toString(v));
}

// Признак открытого вишлиста: наличие блока emptyState («В избранном пока пусто»).
function ymEmptyState(page) export {
    if (page == null) return 0;
    var v = evalStr(
        page,
        "(function(){return document.querySelector('[data-auto=\"emptyState\"]')?1:0;})()"
    );
    if (v == null) return 0;
    return str.toInt(str.toString(v));
}

// Признак гостя: на странице видна кнопка «Войти». У авторизованного
// пользователя такой кнопки нет.
function ymGuestState(page) export {
    if (page == null) return -1;
    var v = evalStr(
        page,
        "(function(){try{var els=document.querySelectorAll('button,a,span,div');"
        + "for(var i=0;i<els.length;i++){var e=els[i];"
        + "if(e.children.length>2)continue;"
        + "var r=e.getBoundingClientRect();if(r.width<1||r.height<1)continue;"
        + "var t=(e.textContent||'').trim();"
        + "if(t==='Войти'||t==='Вход'||t==='Войдите')return 1;}"
        + "return 0;}catch(e){return -1;}})()"
    );
    if (v == null) return -1;
    return str.toInt(str.toString(v));
}

// Прокручивает страницу до конца, чтобы подгрузить все карточки избранного.
// Под вишлистом Яндекс Маркета может идти лента рекомендаций, поэтому
// завершаем прокрутку по стабильности числа карточек, как у Wildberries.
function ymFavScroll(page, maxSteps, stopTrailing) export {
    if (maxSteps == null) maxSteps = ymDefaultMaxScrollSteps;
    if (stopTrailing == null) stopTrailing = ymDefaultStopTrailing;
    if (page == null)
        return #{"count": 0, "complete": false};

    page.evaluate("window.scrollTo(0, 0)");
    system.sleep(0.4);

    var started = system.gettickcount();
    var prev = ymFavCount(page);
    var scanStartedSuccessfully = (prev >= 0);
    print("Начало полной прокрутки: карточек=\(str.toString(prev))");

    var step = 0;
    var stable = 0;
    var scanFailed = false;

    while (step < maxSteps) {
        page.evaluate("window.scrollBy(0, document.documentElement.clientHeight)");
        system.sleep(1.0);

        var n = ymFavCount(page);

        if (n < 0) {
            scanFailed = true;
            break;
        }

        if (n == prev) stable++;
        else stable = 0;

        prev = n;
        step++;

        if (step % 5 == 0)
            print("Прокрутка, шаг \(str.toString(step)): карточек=\(str.toString(n))");

        if (stable >= stopTrailing)
            break;
    }

    var total = ymFavCount(page);
    if (total < 0)
        scanStartedSuccessfully = false;

    print(
        "Полная прокрутка завершена: шагов=" + str.toString(step) +
        ", карточек в DOM=" + str.toString(total) +
        ", время=" + str.toString((system.gettickcount() - started) / 1000.0) + " сек."
    );

    var scanComplete = scanStartedSuccessfully and !scanFailed and
        stable >= stopTrailing;

    return #{"count": total, "complete": scanComplete};
}

// Извлекает карточки избранного из DOM порциями и возвращает массив объектов.
function ymFavCollect(page, total, chunk) export {
    if (chunk == null) chunk = ymDefaultChunk;
    if (page == null) return #[];
    if (total <= 0) return #[];
    var out = #[];
    var from = 0;
    var guard = 0;
    while (from < total and guard < 200) {
        var js = jsYmCardsProbe(from, chunk);
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
function ymCardProduct(cd) export {
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

// Полный цикл обработки избранного: прокрутка, извлечение карточек,
// преобразование записей, фильтрация по признаку избранного и дедупликация.
function ymFavProducts(page, maxSteps, stopTrailing, chunk, includeRecommendations) export {
    if (page == null)
        return #[];

    var scrollResult = ymFavScroll(page, maxSteps, stopTrailing);
    var totalText = str.toString(coalesce(scrollResult.get("count"), "0"));
    var total = str.toInt(totalText);
    var completeValue = scrollResult.get("complete");
    var completeText = str.toString(coalesce(scrollResult.get("complete"), "false"));
    ymScanComplete = (completeValue == true or completeText == "1" or completeText == "true");
    ymFoundIds = #[];

    print(
        "Результат прокрутки: карточек=" + str.toString(total) +
        ", complete=" + completeText
    );

    var recommendationProbe = evalStr(page, jsYmRecommendationsStartProbe());
    var recommendationProbeText = str.toString(coalesce(recommendationProbe, "-2"));
    ymRecommendationStart = str.toInt(recommendationProbeText);

    print("Индекс начала рекомендаций: " + recommendationProbeText);

    if (ymRecommendationStart < 0)
    {
        ymScanComplete = false;
        print("Не найден надёжный маркер начала рекомендаций; членство избранного не будет обновляться.");
    }

    var raw = ymFavCollect(page, total, chunk);
    var rawCount = str.toInt(str.toString(raw.size()));

    if (rawCount != total)
        ymScanComplete = false;

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
        var rawIsRecommendation = ymRecommendationStart >= 0 and
            rawDomIndex >= ymRecommendationStart;
        var pr = ymCardProduct(cd);

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

            ymScanComplete = false;

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
        var isRecommendation = ymRecommendationStart >= 0 and
            domIndex >= ymRecommendationStart;

        if (!isRecommendation)
        {
            if (hasFavoriteMark)
            {
                var seenFavorite = false;

                for (var foundId : ymFoundIds)
                {
                    if (str.toString(foundId) == str.toString(pr.get("id")))
                        seenFavorite = true;
                }

                if (!seenFavorite)
                    ymFoundIds.push(str.toString(pr.get("id")));

                var productUrl = str.toString(coalesce(pr.get("link"), ""));
                if (productUrl != "")
                    pr.set("favorite_link", productUrl);

                pr.set("favorite_state", "in_favorites");
            }
            else
            {
                noheart++;
                ymScanComplete = false;
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
        ymScanComplete = false;

    print("Полное сканирование DOM: \(str.toString(ymScanComplete))");

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

function ymScanWasComplete() export {
    return ymScanComplete;
}

function ymScanIds() export {
    return ymFoundIds;
}

// ---------- Вспомогательные функции ----------

// Возвращает строку, содержащую только цифры из исходного значения.
function onlyDigits(s) {
    var res = "";
    var n = str.len(s);
    for (var i = 0; i < n; i++) {
        var cp = s.codepointat(i);
        if (cp >= 48 and cp <= 57) res = res + str.sub(s, i, 1);
    }
    return res;
}

// Преобразует цену в числовое значение.
function normalizePrice(v) {
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

// Очищает название товара: удаляет лишние пробелы и переносы,
// ограничивает длину 140 символами.
function cleanTitle(v) {
    if (v == null) return "";
    var t = str.trim(str.toString(v));
    t = str.replace(t, "\n", " ");
    if (str.len(t) > 140) t = str.sub(t, 0, 140);
    return str.trim(t);
}

// Проверяет и нормализует идентификатор товара.
// Допускаются только цифровые строки длиной от 4 до 13 символов.
function normalizeId(v) {
    if (v == null) return "";
    var s = str.trim(str.toString(v));
    var n = str.len(s);
    if (n < 4 or n > 13) return "";
    if (onlyDigits(s) == s) return s;
    return "";
}

// Нормализует ссылку на карточку товара: относительные URL преобразует
// в абсолютные, добавляя домен Яндекс Маркета.
function normalizeLink(link) {
    var l = str.trim(str.toString(coalesce(link, "")));
    if (l == "") return "";
    if (str.startswith(l, "http")) return l;
    if (str.startswith(l, "/")) return "https://market.yandex.ru" + l;
    return l;
}

// Извлекает идентификатор товара из ссылки вида:
//   /card/<slug>/<id>/
//   /product/<id>
//   /product--<slug>/<id>
// Возвращает пустую строку, если идентификатор определить не удалось.
function idFromLink(link) {
    if (link == null or link == "") return "";
    var l = str.trim(str.toString(link));
    var q = str.pos(l, "?");
    if (q > 0) l = str.left(l, q);
    var slash = str.rfind(l, "/");
    var tail = "";
    if (slash >= 0) tail = str.sub(l, slash + 1);
    else tail = l;
    tail = onlyDigits(tail);
    var n = str.len(tail);
    if (n >= 4 and n <= 13) return tail;
    return "";
}

// Удаляет дубликаты товаров по идентификатору.
function dedupe(products) {
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
