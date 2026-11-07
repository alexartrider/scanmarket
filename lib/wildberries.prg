// wildberries.prg — разбор страницы избранного Wildberries через DOM.
//
// Класс карточек и способ разметки у Wildberries могут меняться, поэтому
// ориентируемся на устойчивые атрибуты DOM, а не на class-name:
//   - карточка товара: элемент с атрибутом data-nm-id (номер номенклатуры);
//   - ссылка на товар: a[href*="/catalog/"] ... /detail.aspx;
//   - сердечко избранного: кнопка с aria-label «Удалить из избранного»
//     (в избранном) / «Добавить в избранное» (не в избранном), либо svg path
//     с фирменным розовым цветом #CB11AB;
//   - цена: листовые элементы (span/ins/del) с текстом вида "1 234 ₽".
//
// Использование:
// var wb = loadModule("lib/wildberries.prg");
// loadModule регистрирует экспортируемые функции глобально,
// поэтому после загрузки их можно вызывать напрямую.

// URL страницы избранного.
var wbFavoritesUrl = "https://www.wildberries.ru/lk/favorites";

// Максимальное количество шагов прокрутки страницы.
var wbDefaultMaxScrollSteps = 40;

// Количество последовательных шагов без появления новых карточек,
// после которого прокрутка считается завершённой.
var wbDefaultStopTrailing = 5;

// Количество карточек, извлекаемых за один запрос к DOM.
var wbDefaultChunk = 12;

// Цвет SVG-сердечка избранного (фирменный розовый Wildberries).
var wbHeartFill = "#CB11AB";

var wbScanComplete = false;
var wbFoundIds = #[];
var wbRecommendationStart = -1;
var wbRecommendationMarkers = #["Смотрите также", "Похожие товары", "Похожие"];

// Корневой контейнер избранного: сам список или main.
var jsRootProbe = "(function(){"
    + "var r=document.querySelector('#favorites');"
    + "if(r)return r;"
    + "r=document.querySelector('.favorites__goods');"
    + "if(r)return r;"
    + "r=document.querySelector('main');"
    + "if(r)return r;"
    + "return document.body;})()";

// Товары избранного WB помечены testid favorite-product-<id>
// и обёрткой goodsCardFavorites. Не считаем рекомендации ниже списка.
var jsFavoriteTiles = "(function(root){"
    + "var all=root.querySelectorAll('[data-nm-id]');var out=[];"
    + "for(var i=0;i<all.length;i++){var c=all[i];"
    + "var tid=c.getAttribute('data-testid')||'';"
    + "var cls=(typeof c.className==='string'?c.className:'');"
    + "if(tid.indexOf('favorite-product-')===0||cls.indexOf('goodsCardFavorites')>=0)"
    + "out.push(c);}return out;})";

var jsTileCount = "(function(){"
    + "var root=" + jsRootProbe + ";"
    + "return " + jsFavoriteTiles + "(root).length;})()";

// ---------- JS-пробы ----------

// Возвращает индекс первой карточки, начиная с которой идёт блок
// рекомендаций, или -1, если маркер не найден.
function jsWbRecommendationsStartProbe() {
    var markers = json.stringify(wbRecommendationMarkers);
    return "(function(){try{"
        + "var root=" + jsRootProbe + ";"
        + "var tiles=" + jsFavoriteTiles + "(root);"
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
// {total, end, from, cards:[{id,ti,hl,t,o,f,im,u}]}
//
// id    — номер номенклатуры (data-nm-id или из ссылки);
// ti    — название товара;
// hl    — ссылка на товар;
// t     — текущая цена;
// o     — старая цена;
// f     — признак нахождения товара в избранном;
// im    — URL первого изображения внутри этой карточки;
// u     — признак недоступности товара.
function jsWbCardsProbe(from, count) {
    var a = str.toString(from);
    var b = str.toString(count);
    return "(function(){try{"
        + "var RUB=String.fromCharCode(8381);"
        + "var HEART='" + wbHeartFill + "';"
        + "var root=" + jsRootProbe + ";"
        + "var tiles=" + jsFavoriteTiles + "(root);"
        + "var total=tiles.length;"
        + "var out=[];var A=" + a + ";var B=A+" + b + ";if(B>total)B=total;"
        + "for(var i=A;i<B;i++){"
        + "var c=tiles[i];"
        + "var id=c.getAttribute('data-nm-id')||'';"
        + "var as=c.querySelectorAll('a[href*=\"/catalog/\"]');"
        + "var href='';"
        + "for(var z=0;z<as.length;z++){var hh=as[z].getAttribute('href')||'';"
        + "if(hh.indexOf('/catalog/')>=0&&hh.indexOf('detail.aspx')>=0){href=hh;break;}}"
        + "if(href===''&&as.length>0)href=as[0].getAttribute('href')||'';"
        + "if(id===''){var mm=href.match(/(\\d{6,13})(?=[\\/?]|$)/);if(mm)id=mm[1];}"
        + "if(id==='')continue;"
        + "var im='';var bestScore=0;var bestSize=0;var imgs=c.querySelectorAll('img');"
        + "for(var z=0;z<imgs.length;z++){var el=imgs[z];var candidates=[];"
        + "var src=el.getAttribute('src')||el.getAttribute('data-src')||el.getAttribute('data-src-pb')||'';if(src)candidates.push(src);"
        + "if(el.currentSrc)candidates.push(el.currentSrc);"
        + "var ss=el.getAttribute('srcset')||'';if(ss){var sa=ss.split(',');"
        + "for(var si=0;si<sa.length;si++){var su=sa[si].trim().split(/\\s+/)[0];if(su)candidates.push(su);}}"
        + "for(var ci=0;ci<candidates.length;ci++){var cand=candidates[ci];"
        + "if(cand.indexOf('//')===0)cand='https:'+cand;"
        + "var clean=cand.split('?')[0].split('#')[0];var score=0;var size=0;"
        + "if(clean.indexOf('wbbasket.ru')>0){score=1000;"
        + "var sm=clean.match(/\\/c(\\d+)x(\\d+)\\//);"
        + "if(sm)size=parseInt(sm[1],10)*parseInt(sm[2],10);"
        + "if(clean.indexOf('/big/')>0)size=10000000;}"
        + "if(clean.indexOf('wildberries.ru')>0&&score===0)score=500;"
        + "if(score>bestScore||(score===bestScore&&size>bestSize)){bestScore=score;bestSize=size;im=clean;}}}"
        // В выборку попадают только карточки из списка избранного WB.
        // Недоступные товары могут не иметь кнопки сердечка вовсе.
        + "var fav=1;"
        + "var likeBtns=c.querySelectorAll('[data-testid=\"product-card-favorite-button\"],button');"
        + "for(var q=0;q<likeBtns.length;q++){var btn=likeBtns[q];"
        + "var tid=btn.getAttribute('data-testid')||'';"
        + "var cls=(typeof btn.className==='string'?btn.className:'');"
        + "if(tid==='product-card-favorite-button'&&"
        + "(cls.indexOf('active--')>=0||/(^|\\s)active(\\s|$)/.test(cls))){fav=1;break;}"
        + "var al=(btn.getAttribute('aria-label')||'').toLowerCase();"
        + "if(al.indexOf('удалить')>=0||al.indexOf('убрать')>=0){fav=1;break;}}"
        + "var prices=[];var sp=c.querySelectorAll('span,ins,del');"
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
        + "var low=txt.toLowerCase();"
        + "var unavailable=0;"
        + "if(prices.length===0){"
        + "if(low.indexOf('нет в наличии')>=0||low.indexOf('закончился')>=0"
        + "||low.indexOf('уведомить')>=0||low.indexOf('недоступен')>=0)unavailable=1;}"
        + "out.push({id:id,di:i,ti:title,hl:href,t:prices.length?prices[0]:'',"
        + "o:prices.length>1?prices[1]:'',f:fav,im:im,u:unavailable});}"
        + "return JSON.stringify({total:total,from:A,cards:out});"
        + "}catch(e){return 'ERR:'+(e+'');}})()";
}

// Краткая диагностика реальных карточек для уточнения селектора сердечка.
// Не записывает названия, цены, ссылки или содержимое профиля.
function jsWbHeartDiagProbe() {
    return "(function(){try{"
        + "var root=" + jsRootProbe + ";"
        + "var cards=root.querySelectorAll('[data-nm-id]');var out=[];"
        + "for(var i=0;i<cards.length&&i<3;i++){var c=cards[i];"
        + "var item={id:c.getAttribute('data-nm-id')||'',attrs:{},controls:[]};"
        + "for(var a=0;a<c.attributes.length;a++){var at=c.attributes[a];"
        + "if(at.name==='class'||at.name.indexOf('data-')===0)"
        + "item.attrs[at.name]=at.value;}"
        + "var els=c.querySelectorAll('button,[role=button],svg,path,[class*=\"heart\"],[class*=\"like\"]');"
        + "for(var j=0;j<els.length&&j<40;j++){var e=els[j];var n={tag:e.tagName};"
        + "if(typeof e.className==='string')n.cls=e.className;"
        + "for(var k=0;k<e.attributes.length;k++){var x=e.attributes[k];"
        + "if(x.name==='aria-label'||x.name==='aria-pressed'||x.name==='title'"
        + "||x.name==='role'||x.name==='fill'||x.name==='stroke'"
        + "||x.name==='data-state'||x.name==='data-testid')n[x.name]=x.value;}"
        + "item.controls.push(n);}out.push(item);}"
        + "return JSON.stringify({count:cards.length,cards:out});"
        + "}catch(e){return 'ERR:'+(e+'');}})()";
}

// ---------- Проверка доступности страницы ----------

// Определяет, отображается ли вместо избранного антибот-проверка
// Wildberries («Проверяем браузер», «Что-то не так...») или страница входа.
function isWbChallengeTitle(s) export {
    var low = str.lower(str.toString(coalesce(s, "")));
    if (str.pos(low, "проверяем браузер") >= 0) return true;
    if (str.pos(low, "что-то не так") >= 0) return true;
    if (str.pos(low, "подозрительная активность") >= 0) return true;
    if (str.pos(low, "доступ ограничен") >= 0) return true;
    if (str.pos(low, "обратите внимание") >= 0) return true;
    if (str.pos(low, "captcha") >= 0) return true;
    if (str.pos(low, "incident") >= 0) return true;
    if (str.pos(low, "login") >= 0) return true;
    return false;
}

// ---------- Функции управления браузером ----------

// Возвращает количество карточек на странице.
function wbFavCount(page) export {
    if (page == null) return -1;
    var v = evalStr(page, jsTileCount);
    if (v == null) return -1;
    return str.toInt(str.toString(v));
}

// Прокручивает страницу до конца, чтобы подгрузить все карточки.
function wbFavScroll(page, maxSteps, stopTrailing) export {
    if (maxSteps == null) maxSteps = wbDefaultMaxScrollSteps;
    if (stopTrailing == null) stopTrailing = wbDefaultStopTrailing;
    if (page == null)
        return #{"count": 0, "complete": false};

    page.evaluate("window.scrollTo(0, 0)");
    system.sleep(0.4);

    var started = system.gettickcount();
    var prev = wbFavCount(page);
    var scanStartedSuccessfully = (prev >= 0);
    print("Начало полной прокрутки: карточек=\(str.toString(prev))");

    var step = 0;
    var stable = 0;
    var scanFailed = false;

    while (step < maxSteps) {
        page.evaluate("window.scrollBy(0, document.documentElement.clientHeight)");
        system.sleep(1.0);

        var n = wbFavCount(page);

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

        // У WB под списком избранного может идти бесконечная лента
        // рекомендаций. Завершаем, когда количество избранных карточек
        // стабильно, не требуя достижения низа всего документа.
        if (stable >= stopTrailing)
            break;
    }

    var total = wbFavCount(page);
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
function wbFavCollect(page, total, chunk) export {
    if (chunk == null) chunk = wbDefaultChunk;
    if (page == null) return #[];
    if (total <= 0) return #[];
    var out = #[];
    var from = 0;
    var guard = 0;
    while (from < total and guard < 200) {
        var js = jsWbCardsProbe(from, chunk);
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
function wbCardProduct(cd) export {
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
function wbFavProducts(page, maxSteps, stopTrailing, chunk) export {
    if (page == null)
        return #[];

    var scrollResult = wbFavScroll(page, maxSteps, stopTrailing);
    var totalText = str.toString(coalesce(scrollResult.get("count"), "0"));
    var total = str.toInt(totalText);
    var completeText = str.toString(coalesce(scrollResult.get("complete"), "false"));
    wbScanComplete = (completeText == "true");
    wbFoundIds = #[];

    var recommendationProbe = evalStr(page, jsWbRecommendationsStartProbe());
    var recommendationProbeText = str.toString(coalesce(recommendationProbe, "-2"));
    wbRecommendationStart = str.toInt(recommendationProbeText);

    var raw = wbFavCollect(page, total, chunk);
    var rawCount = str.toInt(str.toString(raw.size()));

    if (rawCount != total)
        wbScanComplete = false;

    print("Получено карточек для обработки: \(str.toString(raw.size()))");

    var out = #[];
    var noheart = 0;
    var badid = 0;
    var nopriceN = 0;
    var unavailableN = 0;
    var nopriceIds = "";

    for (var cd : raw)
    {
        var rawDomIndex = str.toInt(str.toString(coalesce(cd.get("di"), "-1")));
        var rawIsRecommendation = wbRecommendationStart >= 0 and
            rawDomIndex >= wbRecommendationStart;
        var pr = wbCardProduct(cd);

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

            wbScanComplete = false;

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
        var isRecommendation = wbRecommendationStart >= 0 and
            domIndex >= wbRecommendationStart;

        if (!isRecommendation)
        {
            if (hasFavoriteMark)
            {
                var seenFavorite = false;

                for (var foundId : wbFoundIds)
                {
                    if (str.toString(foundId) == str.toString(pr.get("id")))
                        seenFavorite = true;
                }

                if (!seenFavorite)
                    wbFoundIds.push(str.toString(pr.get("id")));

                var productUrl = str.toString(coalesce(pr.get("link"), ""));
                if (productUrl != "")
                    pr.set("favorite_link", productUrl);

                pr.set("favorite_state", "in_favorites");
            }
            else
            {
                noheart++;
                wbScanComplete = false;
            }
        }

        if (isRecommendation)
        {
            if (trackedState != null and trackedState.get("enabled") == true)
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
        wbScanComplete = false;

    print("Полное сканирование DOM: \(str.toString(wbScanComplete))");

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

function wbScanWasComplete() export {
    return wbScanComplete;
}

function wbScanIds() export {
    return wbFoundIds;
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
// в абсолютные, добавляя домен Wildberries.
function normalizeLink(link) {
    var l = str.trim(str.toString(coalesce(link, "")));
    if (l == "") return "";
    if (str.startswith(l, "http")) return l;
    if (str.startswith(l, "/")) return "https://www.wildberries.ru" + l;
    return l;
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
