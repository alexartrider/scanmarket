# ScanMarket

ScanMarket периодически читает товары из избранного Ozon, Wildberries и Яндекс Маркета и сохраняет в SQLite сведения о товарах и историю изменения цен. Сейчас реализован этап сбора данных; приложение для просмотра графиков цен — отдельный будущий этап.

## Требования

- Windows.
- Qode: `bin/qodeqt.exe` для сканирования и `bin/qode.exe` для консольных диагностических утилит.
- Поддерживаемый Chromium-браузер: Yandex Browser, Microsoft Edge или Google Chrome.
- Авторизованная учётная запись Ozon для доступа к [Избранному](https://www.ozon.ru/my/favorites).
- Авторизованная учётная запись Wildberries для доступа к [Избранному](https://www.wildberries.ru/lk/favorites).
- Авторизованная учётная запись Яндекс для доступа к [Вишлисту](https://market.yandex.ru/my/wishlist).

Исполняемые файлы, Qt DLL и плагины находятся в `bin/`. Команды ниже запускаются из корня ScanMarket, чтобы относительные пути к конфигурации, данным и профилю браузера разрешались внутри проекта.

GUI открывается через `scanmarket.bat`; BAT-файл сам задаёт корневой рабочий каталог проекта. В окне доступен выпадающий список магазинов (Ozon / Wildberries / Яндекс Маркет) — выбор переключает активную базу и обновляет таблицы товаров, истории цен, карточку и график.

Если GUI был обновлён вручную и нужно вернуть переключатель магазинов, выполните `bin\qodeqt.exe tools\update_gui_stores.prg` (идемпотентно).

## Быстрый запуск

### 1. Авторизовать Ozon

```bat
bin\qodeqt.exe ozon_auth.prg
```

В открывшемся браузере войдите в Ozon и дождитесь отображения списка избранного. Скрипт сохранит cookies в `private_data/ozon/ozon_cookies.json` и штатно закроет браузер.

### 2. Выполнить сканирование

```bat
bin\qodeqt.exe ozon_scan.prg
```

Скрипт открывает браузер с сохранённым профилем, читает карточки избранного, обновляет базу `private_data/ozon/ozon.sqlite`, сохраняет последний снимок в `private_data/ozon/ozon_last_scan.json` и закрывает браузер. Если Ozon запросил повторный вход, выполните авторизацию ещё раз.

### 3. Установить расписание

```bat
bin\qodeqt.exe ozon_setup_cron.prg
```

Скрипт создаёт BAT-файл запуска и задачу планировщика Windows. Параметры задачи находятся в разделе `cron` файла `config.json`. Запустить задачу вручную:

```bat
schtasks /run /tn "ScanMarketOzon"
```

Имя задачи можно изменить через `cron.taskName`.

## Wildberries

Для Wildberries те же шаги, что и для Ozon, но со своими скриптами и настройками.

### 1. Авторизовать Wildberries

```bat
bin\qodeqt.exe wildberries_auth.prg
```

В открывшемся браузере войдите на Wildberries и дождитесь отображения списка избранного. Скрипт сохранит cookies в `private_data/wildberries/wildberries_cookies.json` и штатно закроет браузер. Куки пишутся только если страница избранного действительно загрузилась (карточек больше нуля).

### 2. Выполнить сканирование

```bat
bin\qodeqt.exe wildberries_scan.prg
```

Скрипт открывает браузер с сохранённым профилем, читает карточки избранного, обновляет базу `private_data/wildberries/wildberries.sqlite`, сохраняет последний снимок в `private_data/wildberries/wildberries_last_scan.json` и закрывает браузер. Если Wildberries запросил повторный вход, выполните авторизацию ещё раз.

### 3. Установить расписание

```bat
bin\qodeqt.exe wildberries_setup_cron.prg
```

Параметры задачи находятся в разделе `cronWb` файла `config.json`. Запустить задачу вручную:

```bat
schtasks /run /tn "ScanMarketWildberries"
```

### Проверка сессии Wildberries

```bat
bin\qodeqt.exe wildberries_check_session.prg
```

Проверяет, что страница избранного загружается (карточек больше нуля), и сохраняет свежие куки.

## Яндекс Маркет

Для Яндекс Маркета те же шаги, что и для Ozon и Wildberries, но со своими скриптами и настройками. Избранное находится на странице [Вишлист](https://market.yandex.ru/my/wishlist).

### 1. Авторизовать Яндекс Маркет

```bat
bin\qodeqt.exe yandexmarket_auth.prg
```

В открывшемся браузере войдите на Яндекс. Скрипт сохранит cookies в `private_data/yandexmarket/yandexmarket_cookies.json` и штатно закроет браузер. После входа Яндекс перенаправляет обратно на страницу вишлиста; куки пишутся только если вишлист действительно загрузился (в избранном есть товары либо страница явно показывает пустой вишлист без кнопки «Войти»).

### 2. Выполнить сканирование

```bat
bin\qodeqt.exe yandexmarket_scan.prg
```

Скрипт открывает браузер с сохранённым профилем, читает карточки вишлиста, обновляет базу `private_data/yandexmarket/yandexmarket.sqlite`, сохраняет последний снимок в `private_data/yandexmarket/yandexmarket_last_scan.json` и закрывает браузер. Если Яндекс запросил повторный вход, выполните авторизацию ещё раз.

### 3. Установить расписание

```bat
bin\qodeqt.exe yandexmarket_setup_cron.prg
```

Параметры задачи находятся в разделе `cronYm` файла `config.json`. Запустить задачу вручную:

```bat
schtasks /run /tn "ScanMarketYandexMarket"
```

### Проверка сессии Яндекс Маркета

```bat
bin\qodeqt.exe yandexmarket_check_session.prg
```

Проверяет, что вишлист загружается (в избранном есть товары либо открыт пустой вишлист авторизованного пользователя), и сохраняет свежие куки. Окно браузера остаётся открытым, чтобы в случае антибот-проверки вы могли завершить переход вручную, не теряя вкладку.

## Настройки

Основные параметры `config.json`:

| Параметр | Назначение |
| --- | --- |
| `browser.headless` | Запуск без окна. По умолчанию `false`; для Ozon рекомендуется обычный режим браузера. |
| `browser.execPath` | Путь к `browser.exe`, `msedge.exe` или `chrome.exe`; пустое значение включает автоопределение. |
| `browser.debugPort` | Локальный порт Chrome DevTools Protocol, по умолчанию `9222`. |
| `browser.profileDir` | Каталог профиля браузера, по умолчанию `private_data/browser_profile`. |
| `browser.proxy` | Прокси: пусто — настройки системы, `direct` — обход прокси, другое значение — адрес прокси. |
| `ozon.favoritesUrl` | URL страницы избранного. |
| `ozon.waitLoginSeconds` | Максимальное ожидание входа/готовности страницы. |
| `ozon.pageWaitSeconds` | Ожидание загрузки страницы. |
| `ozon.maxScrollSteps` | Максимальное количество шагов прокрутки списка. |
| `ozon.stopTrailing` | Порог последовательных карточек без признака избранного для завершения списка. |
| `ozon.chunk` | Число карточек в одном запросе к DOM. |
| `wildberries.favoritesUrl` | URL страницы избранного Wildberries. |
| `wildberries.dbPath` | Путь к базе Wildberries, по умолчанию `private_data/wildberries/wildberries.sqlite`. |
| `wildberries.waitLoginSeconds` | Максимальное ожидание входа/готовности страницы Wildberries. |
| `wildberries.pageWaitSeconds` | Ожидание загрузки страницы Wildberries. |
| `wildberries.maxScrollSteps` | Максимальное количество шагов прокрутки списка Wildberries. |
| `wildberries.stopTrailing` | Порог последовательных карточек без признака избранного для завершения списка. |
| `wildberries.chunk` | Число карточек Wildberries в одном запросе к DOM. |
| `yandexmarket.favoritesUrl` | URL страницы вишлиста Яндекс Маркета. |
| `yandexmarket.dbPath` | Путь к базе Яндекс Маркета, по умолчанию `private_data/yandexmarket/yandexmarket.sqlite`. |
| `yandexmarket.waitLoginSeconds` | Максимальное ожидание входа/готовности страницы Яндекс Маркета. |
| `yandexmarket.pageWaitSeconds` | Ожидание загрузки страницы Яндекс Маркета. |
| `yandexmarket.maxScrollSteps` | Максимальное количество шагов прокрутки списка Яндекс Маркета. |
| `yandexmarket.stopTrailing` | Порог последовательных карточек без признака избранного для завершения списка. |
| `yandexmarket.chunk` | Число карточек Яндекс Маркета в одном запросе к DOM. |
| `db.path` | Путь к базе Ozon, по умолчанию `private_data/ozon/ozon.sqlite`. |
| `cron.taskName` | Имя задачи планировщика Windows для Ozon. |
| `cron.mode` | Частота: `daily` или `hourly`. |
| `cron.start` | Время запуска для `daily`, формат `HH:MM`. |
| `cron.everyHours` | Интервал в часах для режима `hourly`. |
| `cron.exe` | Исполняемый файл задачи, обычно `bin/qodeqt.exe`. |
| `cron.script` | Запускаемый скрипт, обычно `ozon_scan.prg`. |
| `cron.bat` | Путь создаваемого BAT-файла. |
| `cron.runLevel`, `cron.np` | Дополнительные параметры уровня запуска и неинтерактивного режима планировщика. |
| `cronWb.*` | Те же параметры планировщика для задачи Wildberries (`taskName`, `mode`, `start`, `everyHours`, `exe`, `script`, `bat`). |
| `cronYm.*` | Те же параметры планировщика для задачи Яндекс Маркета (`taskName`, `mode`, `start`, `everyHours`, `exe`, `script`, `bat`). |

Скрипт дополняет отсутствующие параметры значениями по умолчанию.

## Данные и диагностика

### SQLite

База Ozon — `private_data/ozon/ozon.sqlite`, база Wildberries — `private_data/wildberries/wildberries.sqlite`, база Яндекс Маркета — `private_data/yandexmarket/yandexmarket.sqlite`:

- `products` — карточки товаров, источник, идентификатор, название, бренд, ссылка, наличие и даты обновления;
- `price_points` — история цен, старая цена, валюта, наличие и время фиксации;
- `scan_runs` — журнал запусков, количество найденных товаров, число новых точек цены и статус.

Источник (магазин) хранится в колонке `source` и равен `ozon`, `wildberries` или `yandexmarket`. Новая запись в `price_points` создаётся только при изменении цены. Первое наблюдение товара создаёт первую точку. Времена записываются по локальным часам компьютера.

### Файлы

- `private_data/ozon/ozon_last_scan.json` — результат последнего успешного разбора Ozon.
- `private_data/wildberries/wildberries_last_scan.json` — результат последнего успешного разбора Wildberries.
- `private_data/yandexmarket/yandexmarket_last_scan.json` — результат последнего успешного разбора Яндекс Маркета.
- `bin/log/` — журналы Qode; кодировка журналов может быть CP1251. Старые журналы до переноса движка могут оставаться в `log/`.
- `private_data/ozon/*_dump.html`, `private_data/wildberries/*_dump.html`, `private_data/yandexmarket/*_dump.html` — диагностические HTML-файлы, создаваемые при некоторых ошибках.
- Все приватные данные (базы, куки, профиль браузера) собраны в `private_data/`. Не публикуйте и не передавайте эти файлы.

### Утилита `scanutils`

Диагностические команды выполняются чистым Qode:

```bat
bin\qode.exe tools\scanutils.prg db
bin\qode.exe tools\scanutils.prg db private_data\wildberries\wildberries.sqlite
bin\qode.exe tools\scanutils.prg runs 20
bin\qode.exe tools\scanutils.prg runs 20 private_data\wildberries\wildberries.sqlite
bin\qode.exe tools\scanutils.prg points 20
bin\qode.exe tools\scanutils.prg tail 60
bin\qode.exe tools\scanutils.prg clean 60
bin\qode.exe tools\scanutils.prg grep "auth_required"
bin\qode.exe tools\scanutils.prg cookies private_data\ozon\ozon_cookies.json
bin\qode.exe tools\scanutils.prg dump private_data\ozon\fav_challenge_dump.html
bin\qode.exe tools\scanutils.prg caps
```

Команды `db`, `runs`, `points` и `fixstale` принимают необязательным последним аргументом путь к базе (по умолчанию — база Ozon).

Также доступны команды `fixstale`, `procs`, `readmeinfo`, `cleanroot` и `movefile`. Перед командами, изменяющими данные или перемещающими файлы, проверьте их аргументы в `tools/scanutils.prg`.

## Разбор страницы Ozon

Парсер находится в `lib/ozon.prg` и читает DOM страницы. Он проверяет маркер красного сердечка у карточки, останавливается у блока рекомендаций и ограничивает прокрутку параметрами `ozon.maxScrollSteps` и `ozon.stopTrailing`. Рекламные и рекомендательные карточки отфильтровываются.

Разметка Ozon может измениться. Если товары не распознаны, проверьте авторизацию и антибот-проверку, затем изучите диагностический HTML и журналы. Нулевой результат не следует считать успешным сканированием.

## Разбор страницы Wildberries

Парсер находится в `lib/wildberries.prg` и читает DOM страницы избранного. Карточки списка WB выделяются атрибутом `data-testid="favorite-product-<id>"` и классом `goodsCardFavorites`; номер товара берётся из `data-nm-id`, ссылка — `/catalog/.../detail.aspx`. Карточки из этого контейнера считаются избранными, в том числе недоступные товары без кнопки-сердечка. Прокрутка завершается по стабильности числа таких карточек и не ждёт конца бесконечной ленты рекомендаций. Параметры прокрутки — `wildberries.maxScrollSteps` и `wildberries.stopTrailing`.

Антибот Wildberries может временно показывать страницу «Проверяем браузер» или «Что-то не так...». В этом случае скрипт ждёт и перезагружает страницу. Если товары не распознаны, проверьте авторизацию, затем изучите диагностический HTML в `private_data/wildberries/`. Нулевой результат не следует считать успешным сканированием.

## Разбор страницы Яндекс Маркета

Парсер находится в `lib/yandexmarket.prg` и читает DOM страницы вишлиста. Карточка товара определяется по `[data-auto="snippet-title"]`; идентификатор берётся из ссылки `/card/<slug>/<id>`; цена — из `[data-auto="snippet-price-current"]`. Признак избранного — активное сердечко `[data-auto="wishlist-active"]` внутри карточки (у рекомендаций сердечко неактивное). Блок рекомендаций начинается с заголовка «Достойны сердечка»; карточки после него не считаются избранными. Лента под вишлистом бесконечная, поэтому прокрутка завершается по стабильности числа карточек, как у Wildberries.

Антибот Яндекс Маркета может показывать страницы «Подтвердите, что вы не робот», «Заметили подозрительную активность» или перенаправлять на `passport.yandex.ru`. В этих случаях скрипт ждёт, пока пользователь завершит проверку/вход в открытом окне, без повторных перезагрузок страницы. Сканирование стартует только при подтверждённом входе: в избранном есть товары с активным сердечком либо открыт пустой вишлист без кнопки «Войти» (иначе гостевые рекомендации могли бы быть ошибочно приняты за избранное). Если товары не распознаны, проверьте авторизацию, затем изучите диагностический HTML в `private_data/yandexmarket/` и `yandexmarket_dom_diag.json`.

## Структура проекта

```text
.
├── ozon_auth.prg             # вход в Ozon и сохранение cookies
├── ozon_check_session.prg    # проверка авторизованного избранного
├── ozon_scan.prg             # сканирование и запись истории цен
├── ozon_setup_cron.prg       # создание задачи планировщика Windows
├── wildberries_auth.prg      # вход в Wildberries и сохранение cookies
├── wildberries_check_session.prg # проверка авторизованного избранного Wildberries
├── wildberries_scan.prg      # сканирование Wildberries и запись истории цен
├── wildberries_setup_cron.prg # задача планировщика для Wildberries
├── yandexmarket_auth.prg     # вход в Яндекс Маркет и сохранение cookies
├── yandexmarket_check_session.prg # проверка авторизованного вишлиста Яндекс Маркета
├── yandexmarket_scan.prg    # сканирование Яндекс Маркета и запись истории цен
├── yandexmarket_setup_cron.prg # задача планировщика для Яндекс Маркета
├── config.json               # настройки браузера, магазинов, базы и расписания
├── bin/                      # Qode, Qt DLL, Qt-плагины и плагины Qode
│   ├── qodeqt.exe
│   ├── qode.exe
│   ├── plugins/
│   └── platforms/
├── scriptlib/                # общие библиотеки Script/Qode
├── private_data/             # приватные данные (базы, куки, профиль браузера)
│   ├── ozon/                 # данные магазина Ozon
│   ├── wildberries/          # данные магазина Wildberries
│   ├── yandexmarket/         # данные магазина Яндекс Маркета
│   ├── browser_profile/      # профиль браузера и авторизация
│   └── <новый_магазин>/      # добавляется при подключении нового магазина
├── lib/
│   ├── cdp.prg               # браузер и Chrome DevTools Protocol
│   ├── config.prg            # загрузка конфигурации
│   ├── dbstore.prg           # схема SQLite и операции с данными (source = магазин)
│   ├── ozon.prg              # разбор страницы Ozon
│   ├── wildberries.prg       # разбор страницы Wildberries
│   ├── yandexmarket.prg      # разбор страницы Яндекс Маркета
│   └── scanutil.prg          # функции диагностической утилиты
└── tools/scanutils.prg       # диагностика на qode.exe
```

## Ограничения и безопасность

- Не удаляйте `private_data/browser_profile/`: он нужен для состояния браузера и авторизации.
- Предпочитайте штатное закрытие браузера. Принудительное завершение процесса может помешать сохранению профиля.
- Если сессия Ozon истекла, из корня проекта запустите `bin\qodeqt.exe ozon_auth.prg` и войдите снова.
- Если сессия Wildberries истекла, из корня проекта запустите `bin\qodeqt.exe wildberries_auth.prg` и войдите снова.
- Если сессия Яндекс истекла, из корня проекта запустите `bin\qodeqt.exe yandexmarket_auth.prg` и войдите снова.
- Антибот-защита магазинов может временно блокировать доступ; работа парсера зависит от актуальной разметки сайта.
- Не запускайте одновременно несколько сканирований с одним профилем браузера и одной базой.
- Проверяйте cookies, профиль, базу и HTML-дампы на личные данные перед передачей или публикацией, а лучше вообще не публикуйте.

## План

Текущий этап — сбор товаров и запись изменений цен в SQLite по расписанию. Визуализация истории цен в GUI планируется отдельно.
