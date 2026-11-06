## Синтаксис языка Script

Полная документация: `qt/docs/language.html`, `qt/docs/objects.html`, `qt/docs/functions.html`

### Ключевые слова (поддерживаются обе формы)
```
if/если, else/иначе, for/для, while/пока, do/цикл, return/возврат,
switch/выборпо, case/выбор, default/умолчание, break/прервать,
continue/продолжить, goto/перейти, function/функция, var/перем,
export/экспорт, class/класс, throw/исключение,
try/попытка, catch/перехват, finally/вконце,
and/и, or/или, not/не, uses/использовать, import/импорт, as/как
```

### Типы данных
```
Целое:       42, 0xFF, 0b1010, 0o755         — int64, hex/bin/oct
Вещественное: 3.14, 1e10, .5                  — double
Строка:      "Hello", "val=\(x)"              — UTF-16, интерполяция через \()
Дата:        '2024-01-15', '14.30.00'         — в одинарных кавычках
Логическое:  true, false
Пустое:      null
```

### Константы времени компиляции
```
__FILENAME__  — имя текущего файла
__LINE__      — номер текущей строки
__DATE__      — текущая дата
__TIME__      — текущее время
```

### Escape-последовательности
```
\n       — перевод строки
\t       — табуляция
\\       — обратный слеш
\"       — двойная кавычка
\xNN     — hex-код символа (1-2 цифры)
\uNNNN   — Unicode (4 hex-цифры)
\UNNNNNNNN — Unicode (8 hex-цифр)
\0NN     — восьмеричный код (1-3 цифры)
```

### Многострочные строки
```
"Продолжение строки\
через обратный слеш"

"Склейка: " "две строки"       // результат: "Склейка: две строки"
```

### Коллекции
```
Массив:      #[1, 2, 3]                     — индексируемый список
Кортеж:      #{"a": 1, "b": 2}              — неизменяемый ассоциативный массив
             #tuple{"a": 1}                 — явное создание
Множество:   #{1, 2, 3}                     — уникальные элементы
             #set{1, 2, 3}                  — явное создание
Очередь:     #queue{1, 2}                   — FIFO
Стек:        #stack{1, 2}                   — LIFO
Приоритетная очередь: #priorityqueue{}       — с приоритетами
Словарь:     #dictionary{}                  — ассоциативный массив

Статический массив: var arr[10] = [1,2,3];  — без #, только при объявлении
```

Автоопределение типа `#{...}`: пары `"key": value` → кортеж, простые значения → множество.

### Операторы (приоритет от низшего к высшему)
```
1.  ,                                              — запятая
2.  || / or / или                                  — логическое ИЛИ
2.  && / and / и                                   — логическое И
3.  = += -= *= /= %= &= |= ^= <<= >>=             — присваивание
4.  ? :                                            — тернарный
5.  | ^ &                                          — побитовые: ИЛИ, XOR, И
6.  < > <= >= == !=                                — сравнение
7.  << >>                                          — побитовые сдвиги
8.  + -                                            — сложение / вычитание
9.  * / %                                          — умножение / деление / остаток
10. **                                             — возведение в степень (правоассоциативный)
10. ! not ~ ++ --                                  — унарные
11. . [] ::                                        — доступ: свойство, индекс, скоуп
```

### Функции
```
function add(a, b) { return a + b; }
function helper() export { ... }            — export после списка аргументов
var square = function(x) { return x * x; };
function greet(name = "мир") { print("Привет, \(name)!"); }

// Параметры по умолчанию — любое выражение:
function getData(path = file.getcwd()) { ... }
function calc(x = y + 1) { ... }
function apply(fn = function(x) { return x * 2; }) { ... }
```

### Экспорт
```
function helper() export { ... }            — функция видна извне модуля
var x = 0 export;                           — переменная видна извне модуля
var y export;                               — экспортируемая переменная без инициализации
```

### Управляющие конструкции
```
if (x > 0) { ... } else if (x == 0) { ... } else { ... }
for (var i = 0; i < 10; i++) { ... }
for (var item : arr) { ... }
for (var [key, value] : dict) { ... }     — деструктуризация
while (condition) { ... }
do { ... } while (condition);
switch (x) {
    case 1: ...;
    case 2: ...;
    default: ...;                         // или else:
}
try { ... } catch (e) { ... } finally { ... }
try { ... } catch (TypeError) { ... } catch (Error) { ... }  — несколько catch
```

### Классы
```
class Person {
    var name;
    var age;

    Person(name, age) {
        this.name = name;
        this.age = age;
    }

    function greet() {
        return "Я \(this.name), \(this.age) лет";
    }

    ~Person() { }                         — деструктор
}

class Student : Person {                  — наследование
    var university;
    Student(name, age, university) {
        this::Person(name, age);          — вызов конструктора базового
        this.university = university;
    }
}

var s = Student("Иван", 20, "МГУ");
print(s.greet());          // Я Иван, 20 лет
print(s.university);       // МГУ
```

### Модули
```
uses file;                                      — подключение модуля
uses math;
import math as m;                               — с псевдонимом

file.write("test.txt", "Hello");
math.sqrt(16);                                  — скоуп-обращение
```

### Комментарии
```
// Однострочный комментарий

/*
   Многострочный
   комментарий
*/
```

---

## Методы значений (ScriptValue)

Доступны любому типу:
```
v.size()              — размер (длина строки, кол-во элементов)
v.empty()             — true если пустое
v.isnull()            — проверка на null
v.isbool() / v.isint() / v.isdouble() / v.isnumber() / v.isstring()
v.isdatetime() / v.isarray() / v.istuple() / v.isset()
v.isobject() / v.iscontainer() / v.iscode() / v.isclass()
v.clone()             — глубокая копия
v.type()              — числовой код типа (0..11)
v.typename()          — имя типа: "INT", "STRING", "ARRAY"...
v.json() / v.json(true)  — сериализация в JSON
v.pretty()            — красивый вывод с отступами
v.hash()              — хеш-значение
v.asarray()           — преобразование в массив
v.asbytearray()       — преобразование в массив байт
v.astuple()           — преобразование в кортеж
v.asset()             — преобразование в множество
v.concat(other)       — объединение (изменяет исходное значение)
v.difference(other)   — разность множеств (изменяет исходное значение)
v.intersection(other) — пересечение (изменяет исходное значение)
v.subtract(other)     — вычитание (изменяет исходное значение)
v.forEach(func)       — вызов функции для каждого элемента
```

---

## Глобальные функции

### Вывод и логирование
```
print(args...)          — вывод в консоль с переносом строки
trace(args...)          — вывод уровня TRACE
error(args...)          — вывод уровня ERROR
inspect(val)            — подробная инспекция значения
dump(val)               — дамп значения
help()                  — справка по функциям
```

### Типы и интроспекция
```
type(val)               — числовой код типа: 0=null, 1=int, 2=double, 3=string,
                          4=datetime, 5=array, 6=tuple, 7=set, 10=object
typeName(val)           — имя типа как строка (нижний регистр): "null", "int", "string"...
size(val)               — размер (длина строки, кол-во элементов)
empty(val)              — true если пустое
propertyNames(obj)      — имена свойств объекта
exists(name)            — существует ли переменная
propertyExists(obj, name) — существует ли свойство объекта
methodExists(obj, name)   — существует ли метод объекта
hash(val)               — хеш-значение
```

### Агрегатные функции
```
sum(arr)                — сумма элементов
product(arr)            — произведение
avg(arr) / mean(arr)    — среднее арифметическое
max(a, b)               — максимум из двух значений
min(a, b)               — минимум из двух значений
clamp(val, lo, hi)      — ограничение диапазоном: min(max(val, lo), hi)
median(arr)             — медиана
sumsq(arr)              — сумма квадратов
```

### Работа с коллекциями
```
toarray(val)            — преобразование в массив
push(arr, val)          — добавление элемента
pop(arr)                — извлечение последнего элемента
clear(arr)              — очистка коллекции
sorted(set)             — сортировка (возвращает SET, не массив!)
reversed(arr)           — реверс (возвращает ARRAY)
range(start, [end], [step]) — генерация числового диапазона (возвращает SET)
foreach(arr, func)      — вызов функции для каждого элемента
map(arr, func)          — преобразование каждого элемента
filter(arr, func)       — фильтрация по условию
reduce(arr, func, init) — сворачивание (accumulator)
```

### Форматирование строк (printf-стиль)
```
%s  — строка       %d  — целое       %f  — вещественное
%e  — экспоненц.   %g  — кратчайшее  %x  — hex
%o  — octal        %c  — символ      %%  — литерал %

format("Hello %s, value: %d", "World", 42)  // "Hello World, value: 42"
format("Pi = %.2f", 3.14159)                // "Pi = 3.14"
```

### Области видимости
```
globals()               — все глобальные переменные
scope()                 — текущая область видимости
scopeflat()             — плоский список переменных
```

### JSON (модуль json)
```
json.parse(string)                — разбор JSON-строки → tuple (объект) или array
json.stringify(value, [pretty])   — значение → JSON-строка
json.stringify(value, true, [indent]) — красивый вывод с отступами (по умолчанию 4 пробела)
json.validate(string)             — проверка валидности JSON → true/false
```
Соответствие типов JSON ↔ Script:
| JSON | Script |
|------|--------|
| object `{}` | tuple `#{"key": val}` |
| array `[]` | array `#[...]` |
| string | string |
| number (int) | int |
| number (float) | double |
| true/false | int (1/0) — булевы значения хранятся как int |
| null | null |

### XML (модуль xml)
```
xml.parse(string)        — разбор XML-строки → XmlDocument
xml.load(path)           — загрузка XML из файла → XmlDocument
xml.create(rootName)     — создание нового документа с корневым элементом
```

Методы XmlDocument:
```
doc.child(name)          — первый дочерний элемент по имени
doc.children()           — все дочерние элементы корня (массив XmlNode)
doc.print()              — сериализация в строку (с отступами)
doc.save(path, [indent]) — сохранение в файл (indent=true по умолчанию)
doc.set_root(name)       — добавление корневого элемента → XmlNode
```

Методы XmlNode:
```
node.name()              — имя элемента
node.value()             — значение атрибута value (или "")
node.set_value(val)      — установка значения
node.text()              — текстовое содержимое элемента
node.set_text(val)       — установка текстового содержимого
node.attribute(name)     — значение атрибута по имени (или null)
node.set_attribute(name, val) — установка/создание атрибута
node.child(name)         — первый дочерний элемент по имени
node.children()          — все дочерние элементы (массив XmlNode)
node.parent()            — родительский элемент
node.next_sibling()      — следующий соседний элемент
node.prev_sibling()      — предыдущий соседний элемент
node.append_child(name)  — добавление дочернего элемента → XmlNode
node.remove_child(name)  — удаление дочернего элемента по имени
node.attributes()        — все атрибуты (массив кортежей {name, value})
node.empty()             — true если элемент пуст
node.print()             — сериализация поддерева в строку
```

### Выполнение кода
```
eval(code)              — выполнение строки как кода
execute(path)           — выполнение файла
loadModule(path)        — загрузка модуля
loadPlugin(path, [alias]) — загрузка плагина по пути к .dll
```

### Другое
```
coalesce(a, b, ...)     — первое не-null значение
assert(cond, [msg])     — проверка утверждения
version()               — версия движка
tojson(val)             — алиас json.stringify
fromjson(str)           — алиас json.parse
__FILENAME__            — текущий файл
__LINE__                — текущая строка
```

---

## Модуль str

### Информация
```
str.len(s)              — количество символов
str.empty(s)            — true если строка пуста
str.toString(val)       — преобразование в строку
str.toInt(s)            — преобразование в целое
str.toDouble(s)         — преобразование в вещественное
str.ord(s)              — код первого символа
str.fromCharCode(code)  — Unicode code point (0..0x10FFFF) → строка
```

### Поиск и проверка
```
str.pos(s, sub)         — позиция первого вхождения или -1
str.rpos(s, sub)        — позиция последнего вхождения или -1
str.count(s, sub)       — количество вхождений подстроки
str.startswith(s, prefix) — начинается ли строка с prefix
str.endswith(s, suffix)   — заканчивается ли строка на suffix
str.findany(s, chars)   — позиция первого символа из набора chars
str.findnot(s, chars)   — позиция первого символа НЕ из набора chars
```

### Извлечение
```
str.sub(s, start, [len])    — подстрока. Отрицательные индексы — с конца
str.first(s, [count])       — первые count символов (по умолчанию 1)
str.last(s, [count])        — последние count символов
str.left(s, count)          — count символов с начала
str.right(s, count)         — count символов с конца
str.mid(s, start, len)      — подстрока с позиции start длиной len
str.mid — также доступен как метод строки; отрицательный start отсчитывается с конца
```

### Модификация
```
str.replace(s, from, to)    — замена ВСЕХ вхождений
str.remove(s, sub)          — удаление ВСЕХ вхождений подстроки
str.insert(s, pos, sub)     — вставка подстроки в позицию pos
str.reverse(s)              — разворот строки
str.quoted(s)               — оборачивает в кавычки, экранируя внутренние
str.repeat(s, count)        — повторение строки count раз
```

### Регистр
```
str.upper(s) / str.lower(s)     — регистр
str.swapcase(s)                 — смена регистра каждого символа
str.capitalize(s)               — первая буква заглавная
str.title(s)                    — заглавная первая буква каждого слова
str.iequals(s1, s2)             — сравнение без учёта регистра
```

### Обрезка
```
str.trim(s)                     — пробелы с обоих концов
str.ltrim(s) / str.rtrim(s)    — пробелы слева / справа
str.strip(s, chars)             — указанные символы с обоих концов
str.lstrip(s, chars)            — указанные символы слева
str.rstrip(s, chars)            — указанные символы справа
```

### Заполнение и выравнивание
```
str.pad(s, width, charCode)     — дополнение справа. charCode — int код символа!
str.zfill(s, width)             — дополнение нулями слева
str.center(s, width, [fill])    — центрирование
str.ljust(s, width, [fill])     — выравнивание по левому краю
str.rjust(s, width, [fill])     — выравнивание по правому краю
```

### Преобразования
```
str.itoa(n)                     — целое → строка
str.atof(s)                     — строка → вещественное
str.atoi(s)                     — строка → целое
str.hex(n)                      — в hex (с префиксом 0x)
str.bin(n)                      — в двоичный (с префиксом 0b)
str.oct(n)                      — в восьмеричный (с префиксом 0o)
str.fromCharCode(code)          — код → строка
```

### Статические (глобальные)
```
str.len(s)                  // 5
str.join("-", "a", "b", "c")  // "a-b-c"
str.toInt("42")             // 42
str.toDouble("3.14")        // 3.14
```

---

## Методы строк (instance)

```
s.clear()                       — очистка строки (мутирует)
s.upper() / s.lower()           — регистр
s.trim() / s.ltrim() / s.rtrim() — обрезка пробелов
s.pos(needle)                   — индекс первого вхождения (-1)
s.contains(needle)              — true если найдена (аргумент должен быть строкой, иначе false)
s.split(sep)                    — разбиение на массив
s.splitlines()                  — разбиение по переносам
s.replace(from, to)             — замена ВСЕХ вхождений
s.repeat(n)                     — повтор n раз
s.pad(width, char, side)        — side: 0=справа, 1=слева, 2=центр
s.zfill(width)                  — дополнение нулями слева
s.reverse()                     — разворот
s.sub(start, len)               — подстрока
s.left(count) / s.right(count)  — левые/правые символы
s.mid(start, len)               — подстрока с позиции
s.fromCharCode(code)             — Unicode code point (0..0x10FFFF) → строка
s.first([count]) / s.last([count]) — первые/последние N символов
s.chopped(n)                    — без последних N символов
s.capitalize()                  — первая буква заглавная, остальные строчные
s.title()                       — заглавная первая буква каждого слова
s.count(needle)                 — количество вхождений подстроки
s.startswith(prefix) / s.endswith(suffix)
s.find_first_of(chars)          — первый символ из набора
s.find_last_of(chars)           — последний символ из набора
s.find_first_not_of(chars)      — первый символ НЕ из набора
s.find_last_not_of(chars)       — последний символ НЕ из набора
s.comparenocase(other)          — регистронезависимое сравнение
s.isalnum() / s.isalpha() / s.isdigit()
s.islower() / s.isupper() / s.isspace()
s.regexmatch(pattern)           — true если вся строка совпадает
s.regexsearch(pattern)          — true если частичное совпадение
s.regexreplace(pattern, repl)   — замена по regex
s.regexsplit(pattern)           — разделение по regex
s.regexfindall(pattern)         — все совпадения
s.codepointcount()              — количество codepoints
s.codepointat(i)                — Unicode код символа
s.isvalidutf16()                — проверка UTF-16
s.tocodepoints()                — массив кодов символов
s.extractnumbers()              — извлечение чисел
s.trimtrailingslashes()         — убирает завершающие /
s.toArray()                     — разделение по запятой в массив
s.tobytes()                     — в ByteArray
s.tonumber()                    — преобразование в число
```

---

## Методы массивов

```
arr.clear()                     — очистка
arr.add(v1, v2, ...)            — добавление в конец
arr.push(v1, v2, ...)           — алиас add
arr.pop()                       — удаление и возврат последнего
arr.insert(index, val)          — вставка по индексу
arr.removeAt(index)             — удаление по индексу
arr.remove(val)                 — удаление ВСЕХ вхождений
arr.removeAll(val)              — удаление всех вхождений
arr.swap(i, j)                  — обмен элементов
arr.clone()                     — глубокая копия
arr.size()                      — количество элементов
arr.empty()                     — true если пуст
arr.sort() / arr.sort(func)     — сортировка (по умолчанию или с функцией)
arr.reverse()                   — реверс (мутирует)
arr.reversed()                  — новый отсортированный массив (не мутирует)
arr.unique()                    — удаление дубликатов (после сортировки!)
arr.contains(val)               — true если найден
arr.indexOf(val)                — индекс первого вхождения (-1)
arr.lastIndexOf(val)            — индекс последнего вхождения
arr.includes(val)               — true если присутствует
arr.count(val)                  — количество вхождений
arr.find(func)                  — первый подходящий элемент
arr.every(func)                 — true если ВСЕ удовлетворяют
arr.some(func)                  — true если ХОТЯ БЫ ОДИН
arr.forEach(func)               — для каждого элемента
arr.map(func) / arr.mapped(func)  — новый массив с преобразованиями
arr.filter(func) / arr.filtered(func) — новый массив с фильтрацией
arr.reduce(func, init)          — свёртка
arr.sum()                       — сумма элементов
arr.average()                   — среднее значение
arr.first() / arr.last()        — первый / последний
arr.min() / arr.max()           — минимум / максимум
arr.sliced(start, end)          — часть массива [start, end)
arr.mid(pos) / arr.mid(pos, n)  — срез с позиции
arr.joined(sep)                 — объединение в строку
arr.toString()                  — "[3, 1, 4, 1, 5]"
arr.flattened()                 — новый плоский массив
arr.flatten()                   — раскрытие на месте
arr.grouped(func)               — группировка по ключу
arr.setto(val)                  — заполнение всех элементов
arr.shuffle()                   — перемешивание
arr.tuple()                     — преобразование в кортеж
arr.set()                       — преобразование в множество
arr.sort(func)                  — кастомная сортировка
```

---

## Методы множеств (Set)

```
set.clear()                     — очистка
set.contains(val) / set.has(val) — true если элемент есть
set.add(val)                    — добавление
set.remove(val)                 — удаление
set.isSubsetOf(other)           — true если подмножество
set.isSupersetOf(other)         — true если надмножество
set.symmetricDifference(other)  — только в одном из двух (изменяет исходное значение)
set.equals(other)               — равенство множеств
set.every(func) / set.some(func) — проверка условия
set.reduce(func, init)          — свёртка
set.difference(other)           — разность (изменяет исходное значение)
set.intersection(other)         — пересечение (изменяет исходное значение)
```

---

## Методы кортежей (Tuple)

```
t.clear()                       — очистка
t.contains(key)                 — true если ключ присутствует (то же, что has)
t.keys()                        — массив ключей
t.values()                      — массив значений
t.has(key)                      — true если ключ есть
t.get(key)                      — значение по ключу (null если нет)
t.set(key, val)                 — установка ключ=значение
t.remove(key)                   — удаление по ключу
t.merge(other)                  — объединение (изменяет исходное значение)
t.every(func) / t.some(func)    — проверка условия
t.reduce(func, init)            — свёртка: func(acc, key, value)
```

---

## Методы даты/времени (instance)

```
dt.year()                       — год
dt.month()                      — месяц (1-12)
dt.day()                        — день (1-31)
dt.hour()                       — час (0-23)
dt.minute()                     — минута (0-59)
dt.second()                     — секунда (0-59)
dt.millisecond()                — миллисекунда (0-999)
dt.weekday()                    — день недели (1-7, 1=Пн)
dt.addday(n) / dt.addmonth(n) / dt.addyear(n)
dt.addhour(n) / dt.addminute(n) / dt.addsecond(n)
```

---

## Модуль datetime

### Текущее время
```
datetime.now()                  — текущая дата/время (локальное)
datetime.utcnow()               — текущее UTC
datetime.timezone()             — строковое представление часового пояса
datetime.timezoneoffset()       — смещение UTC в секундах
```

### Создание даты
```
datetime.makedatetime(y, m, d, [H, M, S]) — дата/время из компонентов
datetime.fromtimestamp(ts)      — из Unix timestamp
datetime.parse(str, fmt)        — парсинг строки по формату
```

### Форматирование
```
datetime.strftime(dt, fmt)      — дата → строка по формату
datetime.strptime(str, fmt)     — строка → дата по формату
datetime.datetostring(dt)       — дата как строка
datetime.timetostring(dt)       — время как строка
datetime.datetimetostring(dt)   — дата+время как строка
```

### Арифметика
```
datetime.addday(dt, n) / datetime.addmonth(dt, n) / datetime.addyear(dt, n)
datetime.addhour(dt, n) / datetime.addminute(dt, n) / datetime.addsecond(dt, n)
datetime.subday(dt, n)          — -n дней
```

### Разница между датами
```
datetime.daysdiff(d1, d2)       — разница в днях
datetime.monthsdiff(d1, d2)     — разница в месяцах
datetime.hoursdiff(d1, d2)      — разница в часах
datetime.minutesdiff(d1, d2)    — разница в минутах
datetime.secondsdiff(d1, d2)    — разница в секундах
datetime.interval(d1, d2)       — строковое представление интервала
```

### Компоненты даты
```
datetime.parts(dt)              — {year, month, day, hour, minute, second}
datetime.weekday(dt)            — день недели (0=Пн)
datetime.weekdayname(dt)        — название дня недели
datetime.monthname(dt)          — название месяца
datetime.yearday(dt)            — день года
datetime.weeknumber(dt)         — номер недели
datetime.quarter(dt)            — квартал (1-4)
datetime.timestamp(dt)          — Unix timestamp
```

### Начало/конец периодов
```
datetime.startofday(dt) / datetime.endofday(dt)
datetime.startofweek(dt) / datetime.endofweek(dt)
datetime.startofmonth(dt) / datetime.endofmonth(dt)
datetime.startofquarter(dt) / datetime.endofquarter(dt)
```

### Спецификаторы формата strftime
```
%Y  — год (4 цифры)       %m  — месяц (01-12)     %d  — день (01-31)
%H  — час (00-23)         %I  — час (01-12)       %M  — минута (00-59)
%S  — секунда (00-59)     %a  — день недели корот. %A  — день недели полный
%b  — месяц корот.        %B  — месяц полный       %p  — AM/PM
%j  — день года           %w  — день недели (0-6)  %W  — неделя года
%U  — неделя года (воскресенье)  %x  — дата локально  %X  — время локально
%%  — литерал %
```

---

## Модуль math

### Константы
```
math.pi            — 3.14159...        math.e            — 2.71828...
math.tau           — 6.28318... (2π)   math.phi          — 1.61803... (золотое сечение)
math.sqrt2         — 1.41421... (√2)   math.inf          — ∞
math.nan           — NaN               math.epsilon      — 2.22e-16
math.INT64_MAX     — 9223372036854775807
math.INT32_MAX, math.SIZE_MAX, math.max_double, math.min_double
math.ln2, math.ln10, math.log2e, math.log10e, math.sqrt1_2
```

### Тригонометрия
```
math.sin(x) / math.cos(x) / math.tan(x)
math.asin(x) / math.acos(x) / math.atan(x)
math.atan2(y, x)        — арктангенс(y/x) с учётом квадранта
math.sinh/cosh/tanh(x)  — гиперболические
math.asinh/acosh/atanh(x) — обратные гиперболические
math.degrees(x)         — радианы → градусы
math.radians(x)         — градусы → радианы
```

### Степени, корни, логарифмы
```
math.sqrt(x) / math.cbrt(x)
math.pow(x, y)          — x в степени y
math.hypot(x, y)        — √(x² + y²)
math.exp(x)             — e^x
math.log(x)             — натуральный логарифм
math.log10(x) / math.log2(x)
math.logx(x, base)      — по произвольному основанию
```

### Округление и сравнение
```
math.abs(x) / math.ceil(x) / math.floor(x) / math.trunc(x)
math.round(x, [prec])   — округление (по умолчанию prec=0.01)
math.sign(x)            — знак: -1, 0, 1
math.fmax(a, b) / math.fmin(a, b)
math.clamp(x, min, max) — ограничение диапазоном
math.isclose(a, b, [rt], [at]) — сравнение float
```

### Статистика
```
math.fsum(arr)          — сумма элементов
math.prod(arr)          — произведение
math.mean(arr)          — среднее арифметическое
math.median(arr)        — медиана
math.variance(arr)      — дисперсия (генеральная)
math.stddev(arr)        — стандартное отклонение
math.mode(arr)          — мода
math.pctchange(old, new) — процентное изменение
math.gcd(a, b)          — НОД
math.lcm(a, b)          — НОК
math.factorial(n)       — факториал
```

### Случайные числа
```
math.rand()                 — [0.0, 1.0)
math.randint(min, [max])    — случайное целое [min, max]
```

### Финансовые
```
math.pv(rate, pmt, periods)       — приведённая стоимость аннуитета
math.fv(rate, pmt, periods)       — будущая стоимость аннуитета
math.pmt(rate, principal, periods) — платёж по кредиту
math.npv(rate, cf1, ...)          — чистая приведённая стоимость
```

---

## Модуль file

### Константы
```
file.ENC_UTF16_LE / file.ENC_UTF16_BE / file.ENC_UTF8_BOM
file.ENC_UTF8_NO_BOM / file.ENC_CP1251 / file.ENC_UNKNOWN
file.sep          — основной разделитель (\ на Windows)
file.altsep       — альтернативный (/ на Windows)
file.pathsep      — разделитель PATH (; / :)
```

### Проверка существования и тип
```
file.exists(path) / file.isfile(path) / file.isdir(path) / file.issymlink(path)
```

### Информация о файле
```
file.size(path)             — размер в байтах
file.mtime(path)            — время модификации
file.ctime(path)            — время создания
file.atime(path)            — время доступа
file.isreadonly(path)       — атрибут «Только чтение»
file.ishidden(path)         — атрибут «Скрытый»
```

### Чтение
```
file.read(path, [enc])      — читает как строку (кодировка определяется автоматически; BOM пропускается)
file.readlines(path)        — массив строк (по "\n", срезает "\r"; пустые строки сохраняются;
                              завершающий перевод строки не даёт пустой хвост; пустой файл -> [])
file.readmeta(path)         — #{text, enc, bom}: текст + кодировка (file.ENC_*) + наличие BOM
file.readbytes(path)        — массив int64 значений (каждый элемент — байт)
```

### Запись
```
file.write(path, text, [enc])     — запись строки (UTF-16 LE по умолчанию)
file.writebytes(path, data)       — запись массива байт или ByteArray
file.append(path, text, [enc])    — дописывание в конец файла
```

### Операции с файлами
```
file.copy(src, dst) / file.move(src, dst) / file.remove(path)
file.touch(path)            — обновление mtime (или создание)
```

### Директории
```
file.mkdir(path)                    — создание директории
file.mkdirrecursive(path)           — создание со всеми промежуточными
file.rmdir(path)                    — удаление пустой директории
file.rmdirrecursive(path)           — удаление со содержимым (!)
file.dir([path, [pattern]])         — список файлов/папок
file.dirrecursive([path, [pattern]]) — рекурсивный обход
```

### Работа с путями
```
file.basename(path)         — имя файла с расширением
file.filename(path)         — имя файла без расширения
file.dirname(path)          — путь к родительской директории
file.extension(path)        — расширение (с точкой)
file.absolute(path)         — абсолютный путь
file.relative(path, base)   — относительный путь от base
file.join(p1, p2, ...)      — безопасное склеивание путей
file.normalize(path)        — нормализация (убирает .. и лишние /)
file.split(path)            — разделение на (dir, file)
file.splitext(path)         — разделение на (name, ext)
file.expanduser(path)       — замена ~ на домашнюю директорию
file.realpath(path)         — канонический путь
file.samefile(p1, p2)       — один и тот же файл
```

### Системные пути и окружение
```
file.homedir()              — домашняя директория
file.tempdir()              — временная директория
file.tempfile()             — временный файл
file.getcwd()               — текущая рабочая директория
file.chdir(path)            — смена рабочей директории
file.getenv(name)           — переменная окружения
file.setenv(name, val)      — установка переменной окружения
file.environ()              — все переменные окружения
file.space(path)            — информация о диске
```

---

## Модуль ByteArray

### Создание
```
var ba = ByteArray()                                — новый пустой
var ba = ByteArray.fromString("Привет", ByteArray.encode_utf8)
var ba = ByteArray.fromHex("48656C6C6F")
var ba = ByteArray.fromBase64("SGVsbG8=")
```

### Константы кодировок
```
ByteArray.encode_utf8 / ByteArray.encode_cp1251 / ByteArray.encode_cp866
ByteArray.encode_hex / ByteArray.encode_base64
```

### Свойства
```
ba.size / ba.length / ba.empty / ba[i]
```

### Методы
```
ba.size() / ba.empty() / ba.clear()
ba.push(byte) / ba.pop() / ba.unshift(byte) / ba.shift()
ba.setsize(n) / ba.resize(n, [fill])
ba.get(offset, count) / ba.set(offset, arr)
ba.find(byte, [start]) / ba.indexOf(byte)
ba.reverse() / ba.fill(byte) / ba.sort() / ba.clone()
ba.toString([enc]) / ba.hex() / ba.base64() / ba.crc32()
```

---

## Модуль Log

### Свойства
```
Log.IsWindowsTerminal     — запущен ли в Windows Terminal
Log.console               — видимость окна консоли (bool, чтение/запись)
Log.filePrefix            — префикс имени лог-файла
Log.remoteFilePath        — путь к удалённому лог-файлу
Log.localFilePath         — путь к локальному лог-файлу
Log.writeToRemote         — запись в удалённый файл
Log.writeToLocal          — запись в локальный файл
```

### Методы
```
Log.rotate()              — ротация лог-файла
Log.print(args...)        — вывод в консоль
Log.trace(args...)        — трассировка (уровень TRACE)
Log.error(args...)        — ошибка (уровень ERROR)
Log.format(args...)       — форматирование без вывода
Log.consoleInfo()         — снимок состояния консоли: attached, visible,
                            stdoutIsConsole, stderrIsConsole, outputRedirected,
                            outputCodePage, inputCodePage, stdoutMode, stderrMode,
                            vtProcessing, processedOutput, ansiColorsEnabled,
                            lastError, refreshSucceeded
Log.refreshConsole()      — перепроверка дескрипторов и повторное применение режимов
                            вывода (после дочерних процессов). Без FreeConsole/AllocConsole
```

---

## Модуль system

### Выполнение процессов
```
system.system(cmd)                  — синхронное выполнение команды
system.systemex(cmd, [timeout])     — с таймаутом. Возвращает {success, code, killed}
system.systemasync(cmd, [workDir], [timeout], [options])
                                    — асинхронное. Возвращает объект Process.
                                      options = #{"console": "inherit"|"new"|"detached"}:
                                      "inherit" — общая консоль (по умолчанию);
                                      "new"     — отдельная консоль (CREATE_NEW_CONSOLE);
                                      "detached" — без консоли родителя (DETACHED_PROCESS)
```

### Объект Process
```
p.isReady       — процесс завершён
p.runtime       — время выполнения (мсек)
p.result        — результат {success, code, killed}
p.kill()        — завершение процесса
```

### Окружение
```
system.env()                        — переменные окружения
system.getcommandline()             — аргументы командной строки: app/basename/dirname/filename,
                                      argv0, raw (все по порядку), args (не-флаги), count,
                                      flags (tuple; повтор сохраняет первое значение),
                                      parsed (упорядоченные токены: flag/value/pos/end для "--")
```

### Профилирование
```
system.sleep(ms)                    — пауза в миллисекундах
system.gettickcount()               — текущее время (мсек) для профилирования
system.timeit(func, args...)        — замер времени выполнения функции
system.benchmark(func, n)           — бенчмарк: n вызовов функции
```

### Системная информация
```
system.computername()               — имя компьютера
system.username()                   — имя пользователя
system.cpuid()                      — идентификатор CPU
system.vendor()                     — производитель CPU
system.id()                         — уникальный идентификатор
```

### Управление питанием
```
system.shutdown() / system.reboot() / system.logoff()
```

### Звук
```
system.beep(freq, duration)         — звуковой сигнал
system.messagebeep(type)            — системный звук
```

### Ввод/вывод и управление
```
system.write(text)                  — запись без переноса строки
system.writeln(text)                — запись с переносом строки
system.exit(code)                   — завершение с кодом
system.abort()                      — аварийное завершение
```

---

## Геометрические примитивы

### QodePoint
```
var p = QodePoint(10, 20);

Свойства: x, y (чтение/запись)

Методы:
p.add(p|s|x,y)             — сложение (возвращает QodePoint)
p.subtract(p|s|x,y)        — вычитание
p.scale(factor)             — масштабирование
p.offset(s|x,y)             — смещение (alias для add)
p.setlocation(x,y)          — установка координат
p.negate() / p.abs()        — инверсия / модуль
p.min(p|x,y) / p.max(p|x,y) — покомпонентный мин/макс
p.clamp(min, max)           — ограничение диапазоном
p.rotate(angle, center?)    — поворот (радианы)
p.lerp(target, t)           — линейная интерполяция (t: 0..1)
p.distance(p|x,y)           — расстояние до точки
p.length()                  — длина вектора от (0,0)
p.angle(p|x,y)              — угол до точки (atan2)
p.normalize()               — нормализация (длина = 1)
p.ptincircle(center, radius) — проверка вхождения в круг
p.equals(p) / p.iszero() / p.isempty()
p.clone() / p.toarray() / p.toQodeSize()
```

### QodeSize
```
var s = QodeSize(100, 200);

Свойства: cx, cy (чтение/запись)

Методы:
s.add(s|cx,cy) / s.subtract(s|cx,cy) / s.scale(factor)
s.swap()                    — обмен cx/cy
s.fit(target)               — масштабирование с сохранением пропорций
s.expand(s) / s.reduce(s)  — покомпонентный max/min
s.aspect()                  — соотношение сторон (cx/cy)
s.area() / s.maxside() / s.minside()
s.equals(s) / s.iszero() / s.clone()
s.toarray() / s.toQodePoint()
```

### QodeRect
```
var r = QodeRect(0, 0, 100, 200);           — (left, top, right, bottom)
var r = QodeRect(QodePoint, QodeSize);
var r = QodeRect(QodePoint1, QodePoint2);

Свойства: left, top, right, bottom, width, height,
          topleft, bottomright, location, QodeSize

Методы трансформации:
r.move(p|x,y) / r.offset(p|s|x,y)
r.inflate(s|dx,dy|d) / r.shrink(s|dx,dy|d)
r.scale(sx, [sy]) / r.normalize() / r.round()

Геометрические операции:
r.union(r) / r.intersect(r) / r.fit(target) / r.split(cols, rows)

Запросы:
r.contains(p|x,y) / r.containsQodeRect(r) / r.intersects(r)
r.center() / r.aspect() / r.area()
r.isempty() / r.iszero() / r.equals(r) / r.clone()
r.setQodeRect(l,t,r,b)
```

**Важно:** `add`, `subtract`, `scale`, `inflate` — **мутируют** объект (возвращают `shared_from_this()`).

---

## Модули qt (QT-специфичные)

### QT-модули
```
qt.XlsxDocument() / qt.QXlsxDocument()  — документ Excel (XLSX)
 详见 qt/docs/xlsx.html
```

---

## Плагины

Плагины загружаются через `loadPlugin`. `uses` — только для встроенных модулей.
```
loadPlugin("archive7zip");              // загрузка по имени
loadPlugin("archive7zip", "zip");       // с псевдонимом
```

### Доступные плагины
| Плагин | Описание |
|--------|----------|
| `archive7zip` | Архивы 7z/ZIP/TAR/GZIP (через 7z.exe) |
| `clipboard` | Буфер обмена Windows — текст и изображения |
| `comport` | COM-порты |
| `crypto` | Криптография |
| `dbf` | Чтение/запись DBF |
| `ftpclient` | FTP-клиент |
| `http` | HTTP/HTTPS клиент и сервер |
| `websocket` | WebSocket клиент |
| `imap` | IMAP-клиент |
| `inicsv` | INI и CSV файлы |
| `max` | Бот MAX Messenger (Bot API, Long Polling) |
| `registry` | Реестр Windows |
| `screen` | Скриншоты, захват экрана |
| `smtp` | SMTP-отправка |
| `tcp` | TCP-клиент/сервер |
| `udp` | UDP-клиент/сервер |

Подробная справка: `qt/docs/plugins.html`, `qt/docs/plugin_development.html`

---

## Модуль http

### Создание
```
loadPlugin("plugins/http.dll");
var http = HttpClient();
```

### Запросы
```
http.get(url)                                    — GET-запрос
http.post(url, [body], [contentType])            — POST
http.put(url, [body], [contentType])             — PUT
http.del(url)                                    — DELETE
http.patch(url, [body], [contentType])           — PATCH
http.head(url)                                   — HEAD
http.request(method, url, [body], [contentType]) — произвольный метод
```

### Загрузка файлов
```
http.download(url, filePath)                     — скачивание на диск
http.upload(url, filePath, [fieldName])          — multipart/form-data загрузка
```

### Заголовки и аутентификация
```
http.setHeader(name, value)                      — заголовок запроса
http.clearHeaders()                              — очистка заголовков + auth
http.setBasicAuth(user, pass)                    — Basic Auth
http.setBearerAuth(token)                        — Bearer Token
http.setUserAgent(ua)                            — User-Agent
```

### Конфигурация
```
http.setTimeout(ms)                              — таймаут (мсек)
http.setFollowRedirects(bool)                    — авто-редиректы (по умолч. true)
http.setProxy(host, port)                        — HTTP-прокси
http.setVerifySsl(bool)                          — проверка SSL-сертификатов
```

### Результат
```
http.status()                                    — HTTP-статус (200, 404...)
http.statusText()                                — текст статуса (OK, Not Found)
http.getResponse()                               — тело как строка
http.getResponseBytes()                          — тело как ByteArray
http.getHeader(name)                             — заголовок ответа
http.getResponseHeaders()                        — все заголовки ответа
http.lastError()                                 — последняя ошибка
```

### Утилиты
```
http.urlEncode(str)                              — URL-кодирование
http.urlDecode(str)                              — URL-декодирование
http.getMimeType(filename)                       — MIME-тип по расширению
http.connect(host, port, [ssl])                  — ручное подключение
http.disconnect()                                — отключение
http.isconnected()                               — проверка соединения
```

### Пример
```
loadPlugin("plugins/http.dll");
var http = HttpClient();
http.get("https://httpbin.org/get");
if (http.status() == 200) {
    print(http.getResponse());
}

http.post("https://httpbin.org/post",
    "{\"key\":\"value\"}", "application/json");

http.download("https://example.com/file.zip", "file.zip");
```

## Модуль http (HTTP-сервер)

### Создание
```
var server = HttpServer();
```

### Методы сервера
```
server.listen(port)                                   — начать прослушивание порта
server.stop()                                         — остановить сервер
server.islistening()                                  — проверка состояния прослушивания
server.port()                                         — номер текущего порта
server.process([timeout_ms])                          — обработать запрос (возвращает tuple/null)
server.respond(socketId, responseTuple)               — отправить ответ и закрыть соединение
server.lastError()                                    — последняя ошибка
```

### process(timeout_ms)
Ожидает входящий запрос в течение timeout_ms (по умолчанию 50 мс).
Возвращает кортеж запроса или null если запросов нет.

Кортеж запроса:
```
req.method       — HTTP-метод (GET, POST, ...)
req.path         — путь запроса (/api/data)
req.query        — строка запроса (q=test&page=1)
req.body         — тело запроса
req.headers      — заголовки запроса (кортеж)
req.port         — порт сервера
req.socket       — идентификатор соединения (для respond)
```

### respond(socketId, responseTuple)
Отправляет HTTP-ответ и закрывает соединение.

Кортеж ответа:
```
response.status      — HTTP-статус (по умолчанию 200)
response.statusText  — текст статуса (по умолчанию "OK")
response.body        — тело ответа
response.headers     — заголовки ответа (кортеж)
```

### Пример
```
loadPlugin("plugins/http.dll");

var server = HttpServer();
server.listen(8080);

var handler = function(req) {
    print(req.method + " " + req.path);
    return #{
        "status": 200,
        "statusText": "OK",
        "headers": #{"Content-Type": "text/plain"},
        "body": "Hello, World!"
    };
};

while (server.islistening()) {
    var req = server.process(100);
    if (req != null) {
        var resp = handler(req);
        server.respond(req.socket, resp);
    }
}
```

---

## Модуль websocket (WebSocket-клиент)

### Создание
```
loadPlugin("plugins/websocket.dll");
var ws = WebSocket();
```

### Подключение
```
ws.connect(url)     — ws:// или wss://. Возвращает bool
ws.disconnect()     — отключение без close-фрейма
ws.isconnected()    — проверка подключения
ws.close()          — корректное закрытие (close-фрейм)
```

### Сообщения
```
ws.send(text)           — отправка текста. Возвращает bool
ws.sendBinary(data)     — отправка ByteArray или строки. Возвращает bool
ws.recv()               — получение текста (string|null)
ws.recvBinary()         — получение ByteArray (ByteArray|null)
ws.ping()               — отправка ping-фрейма. Возвращает bool
```

### Очередь сообщений
```
ws.hasMessage()         — есть ли сообщения. Возвращает bool
ws.messageCount()       — количество в очереди. Возвращает int
ws.clearMessages()      — очистка очереди. Возвращает bool
```

### Конфигурация
```
ws.setTimeout([ms])     — таймаут чтения (мсек). Геттер без аргументов
ws.lastError()          — последняя ошибка (string|null)
```

### Пример
```
loadPlugin("plugins/websocket.dll");
var ws = WebSocket();
if (ws.connect("wss://echo.websocket.events")) {
    ws.send("Hello!");
    system.sleep(1000);
    var msg = ws.recv();
    print(msg);   // Hello!
    ws.close();
}
```

---

## Модуль ssh (SSH/SCP/SFTP)

### Создание
```
var session = ssh.connect();           — создаёт объект сессии
```

### Информация
```
ssh.version()                          — версия libssh2
```

### Методы сессии (session)

#### Подключение
```
session.connect(host, port, user, pass) — подключение по SSH (возвращает bool)
session.disconnect()                   — отключение
session.isconnected()                  — проверка подключения
session.last_error()                   — последняя ошибка
```

#### Выполнение команд
```
session.exec(command)                  — выполнение команды (возвращает stdout+stderr)
```

#### SCP (передача файлов)
```
session.scp_send(remote_path, data)    — отправка данных на удалённый файл
session.scp_recv(remote_path)          — скачивание удалённого файла (возвращает строку)
```

#### SFTP (файловая система)
```
session.sftp_init()                    — инициализация SFTP-сессии (возвращает bool)
session.sftp_open(path, mode)          — открытие файла (mode: "r", "w", "a", "rb", "wb")
session.sftp_read(handle, max_bytes)   — чтение данных из файла
session.sftp_write(handle, data)       — запись данных в файл
session.sftp_close(handle)             — закрытие файла
session.sftp_readdir(path)             — список файлов в директории
session.sftp_mkdir(path)               — создание директории
session.sftp_rmdir(path)               — удаление директории
session.sftp_unlink(path)              — удаление файла
session.sftp_rename(old_path, new_path)— переименование файла
session.sftp_stat(path)                — информация о файле {size, mode, mtime, atime, isdir}
```

### Пример
```
var session = ssh.connect();
if (session.connect("192.168.1.1", 22, "user", "pass")) {
    // Выполнение команды
    var result = session.exec("ls -la");
    print(result);
    
    // SFTP: запись файла
    var h = session.sftp_open("/tmp/test.txt", "w");
    session.sftp_write(h, "Hello!");
    session.sftp_close(h);
    
    // SFTP: чтение файла
    var h2 = session.sftp_open("/tmp/test.txt", "r");
    var content = session.sftp_read(h2, 1024);
    print(content);
    session.sftp_close(h2);
    
    // SCP: отправка файла
    session.scp_send("/tmp/remote.txt", "data to send");
    
    session.disconnect();
}
```

---

## Модуль snmp (SNMP мониторинг)

### Создание
```
var s = snmp.open();                   — создаёт объект сессии
```

### Методы сессии

#### Подключение
```
s.open(host, port, community, version?) — UDP-подключение (version: "v1"/"v2c", по умолчанию "v2c")
s.close()                               — закрытие сокета
s.isopen()                              — 1 если открыт
s.timeout(ms?)                          — геттер/сеттер таймаута (мсек, по умолчанию 3000)
s.last_error()                          — последняя ошибка
```

#### Запросы
```
s.get(oid...)                           — SNMP GET (одна или несколько OID)
s.getnext(oid...)                       — SNMP GETNEXT
s.getbulk(non_reps, max_reps, oid...)   — SNMP GETBULK (только v2c)
s.set(oid, value, type?)                — SNMP SET (type: "int"/"octet"/"counter"/"gauge"/"timeticks"/"ip"/"null")
s.walk(root_oid, max?)                  — GETNEXT-обход от root_oid (возвращает массив)
```

### Ответ
```
{
    "version":     1,                   — 0=SNMPv1, 1=SNMPv2c
    "community":   "public",
    "request_id":  1,
    "error_status": 0,                  — 0=noError
    "error_index":  0,
    "pdu":         "GetResponse",
    "varbinds": [
        { "oid": "1.3.6.1.2.1.1.1.0", "type": "STRING", "value": "RouterOS CCR1009..." }
    ]
}
```

### Пример
```
var s = snmp.open();
s.open("192.168.111.1", 161, "public");
s.timeout(3000);

print(s.get("1.3.6.1.2.1.1.1.0").varbinds[0].value);
print(s.get("1.3.6.1.2.1.1.5.0").varbinds[0].value);

var entries = s.walk("1.3.6.1.2.1.2.2.1.2");
for (var e : entries) {
    print(e.oid + " -> " + e.value);
}
s.close();
```

---

## Модуль sqlite (нативная SQLite)

### Создание
```
var db = sqlite.open("data.db");     — открыть или создать файл базы
var mem = sqlite.memory();            — база данных в памяти
sqlite.version();                     — версия SQLite
```

### Методы базы
```
db.exec(sql, params?)                 — выполнить SQL без выборки
db.execute(sql, params?)              — алиас exec
db.query(sql, params?)                — SELECT → массив кортежей
db.scalar(sql, params?)               — первое поле первой строки
db.begin() / db.commit()              — транзакция
db.rollback()                         — откат транзакции
db.changes()                          — количество изменённых строк
db.last_insert_rowid()                — ID последней вставленной строки
db.isopen() / db.close()              — состояние и закрытие базы
db.last_error()                       — текст последней ошибки
```

### Параметры
```
db.exec("insert into t(value) values (?)", #["text"]);
db.exec("insert into t(value) values (:value)", #{":value": "text"});
```

### Типы
```
NULL    → null
INTEGER → целое число
REAL    → вещественное число
TEXT    → строка
BLOB    → массив числовых байтов
```

### Пример
```
var db = sqlite.memory();
db.exec("create table people(id integer primary key, name text, age integer)");
db.exec("insert into people(name, age) values (?, ?)", #["Alice", 30]);

var rows = db.query("select id, name, age from people");
for (var row : rows) {
    print(row.id + ": " + row.name + ", " + row.age);
}
db.close();
```

---

## Модуль inicsv (INI/CSV)

Загрузка:
```
loadPlugin("plugins/inicsv.dll");
```

### Кодировки
```
"utf8"      — UTF-8 без BOM
"utf8bom"   — UTF-8 с BOM
"utf16"     — UTF-16 LE
"cp1251"    — Windows-1251 (по умолчанию для новых файлов)
"auto"      — сохранить кодировку существующего файла
```
Чтение определяет кодировку автоматически (BOM + эвристика). Если при записи кодировка не указана
или передана как `"auto"` и файл уже существует — сохраняется его кодировка; для нового файла — `cp1251`.

### CSV

```
csvRead(filename, fields, [encoding|separator], [separator])  — чтение в массив кортежей
csvWrite(filename, fields, data, [encoding], [separator])     — запись, возвращает 1/0
csvRowCount(filename)                                         — число строк данных (без заголовка)
```

- `fields` — строка `"a;b;c"` или массив `#["a","b","c"]` (ожидаемые колонки);
- разделитель по умолчанию `";"`; передаётся 4-м аргументом или 3-м вместо кодировки;
- заголовок CSV — первая строка файла (csvRead) или `fields` (csvWrite);
- csvWrite принимает `data` как массив (или кортеж) кортежей/массивов строк; строки не-табличного типа пропускаются;
- значения: пустая строка → `null`, целые числа → `int`, вещественные → `double`, `true/yes` → `1`, `false/no` → `0`, остальное — строка;
- отсутствующие ожидаемые поля заполняются `null`;
- RFC-разбор: кавычки и разделители внутри полей, многострочные поля, CRLF/LF/CR, BOM, `""` — экранирование кавычки;
- при записи значения с разделителями, кавычками, пробелами по краям или переносами строк оборачиваются в `"` (`"` → `""`), строки разделяются CRLF.

```
var rows = csvRead("data.csv", "name;age;city", "utf8");
print(rows[0].name);    // "Ivan"
print(rows[0].age);     // 30 (int)

// Массив полей и разделитель-запятая
var rows = csvRead("data.csv", #["x","y"], "utf8", ",");

// Запись
var data = #[
    #{"name": "Ivan", "age": 30, "city": "Moscow"},
    #{"name": "Anna", "age": 25, "city": "SPb"}
];
csvWrite("data.csv", #["name","age","city"], data, "utf8");
```

### INI

```
iniRead(filename)                       — чтение файла в кортеж кортежей {section: {key: value}}
iniWrite(filename, data, [encoding])    — запись кортежа секций, возвращает 1/0
iniReadValue(filename, section, key)    — одно значение или null
iniWriteValue(filename, section, key, value, [encoding]) — запись/обновление, возвращает 1/0
```

- `data` для iniWrite — кортеж `#{"section": #{"key": value, ...}, ...}`;
- значения типизируются: числа → `int`/`double`, остальное — строка (пустое значение → пустая строка);
- комментарии `;` и `#` пропускаются; заголовок секции может заканчиваться комментарием: `[section] ; note`;
- iniWriteValue обновляет существующий файл in-place: заменяет ключ, добавляет в конец секции или создаёт новую секцию.

```
var config = #{
    "database": #{"host": "localhost", "port": 5432},
    "server": #{"bind": "0.0.0.0", "timeout": 30}
};
iniWrite("config.ini", config, "utf8");

var host = iniReadValue("config.ini", "database", "host");  // "localhost"
iniWriteValue("config.ini", "database", "port", 3306, "utf8");
```

---

## Модуль max (MAX Messenger Bot API)

Загрузка:
```
loadPlugin("plugins/max.dll");
```

### Создание
```
var mx = maxclient();
```

### Подключение
```
mx.connect(token)        — проверка токена (GET /me) и запоминание данных бота; 1/0
mx.disconnect()          — отключение, очистка очереди и маркера; 1
```
Токен бота выдаётся на business.max.ru и передаётся заголовком `Authorization`.

### Отправка
```
mx.send(recipientId, text)              — сообщение пользователю (POST /messages?user_id=)
mx.send(recipientId, text, "chat")      — сообщение в чат/канал (POST /messages?chat_id=)
mx.send(recipientId, text, "channel")   — то же, что "chat"
```
Третий аргумент `mode`: если равен `"chat"` или `"channel"` — `recipientId` трактуется как
`chat_id`; при любом другом значении или отсутствии аргумента — как `user_id` (диалог).

### Приём (Long Polling)
```
mx.recv()                — следующее сообщение (tuple) или null; при пустой очереди опрашивает GET /updates
mx.hasMessage()          — 1/0
mx.messageCount()        — число сообщений в очереди
mx.setTimeout(sec)       — таймаут Long Polling, 1–90 (по умолчанию 30); без аргумента — геттер
```
Поля кортежа `recv()`: `type`, `timestamp`, `message_id`, `text`, `sender_id`,
`sender_first_name`, `sender_last_name`, `sender_username`, `sender_is_bot`, `chat_id`, `chat_type`.

### SSL и ошибки
```
mx.setVerify([bool])     — проверка SSL-сертификата (по умолчанию выключена)
mx.setCA(file)           — свой файл CA для проверки цепочки
mx.lastError()           — последняя ошибка
```
Свойства: `mx.connected`, `mx.pollTimeout`, `mx.botUsername`.

---

## Примеры из sample/

### Классы и наследование
```
class Animal {
    Animal(name, sound) {
        this.name = name;
        this.sound = sound;
    }
    function speak() {
        return "\(this.name) говорит \(this.sound)!";
    }
}

class Dog : Animal {
    Dog(name) : Animal(name, "Гав") {   // вызов базового конструктора
        this.tricks = 0;
    }
    function fetch() {
        this.tricks = this.tricks + 1;
        return "\(this.name) приносит палку! (трюк #\(this.tricks))";
    }
}

var rex = Dog("Рекс");
print(rex.speak());       // Рекс говорит Гав!
print(rex.fetch());       // Рекс приносит палку! (трюк #1)
```

### Коллекции — методы
```
var arr = #[3, 1, 4, 1, 5];
arr.size();                   // 5
arr.empty();                  // false
arr.sort(); arr.reverse(); arr.clear();
arr.add(6); arr.push(7, 8); arr.pop();
arr.insert(0, 99); arr.removeAt(0); arr.remove(4); arr.removeAll(1);
arr.swap(0, 2); arr.clone();
arr.contains(4); arr.indexOf(4); arr.lastIndexOf(1); arr.count(1);
arr.min(); arr.max(); arr.sum(); arr.average();
arr.sliced(0, 3); arr.mid(1); arr.mid(1, 3); arr.first(); arr.last();
arr.sort(function(a, b) { return a - b; });  // кастомная сортировка
arr.reversed();               // новый массив (не мутирует)
arr.forEach(function(x) { print(x); });
arr.map(function(x) { return x * 2; });
arr.filter(function(x) { return x > 2; });
arr.some(function(x) { return x > 3; });
arr.every(function(x) { return x > 0; });
arr.grouped(function(w) { return w.first(); });
arr.joined(", ");             // "3, 1, 4, 1, 5"
arr.toString();               // "[3, 1, 4, 1, 5]"

// Глобальные функции
var doubled = map(arr, function(x) { return x * 2; });
var evens = filter(arr, function(x) { return x % 2 == 0; });
var total = reduce(arr, function(acc, x) { return acc + x; }, 0);
var r = range(1, 10);          // множество {1..9}
var s = sorted(arr);           // множество (отсортированное)
var rev = reversed(arr);       // массив (реверсированный)

// Tuple (ассоциативный массив)
var t = #{"name": "Иван", "age": 30};
t.keys(); t.values(); t.get("name"); t.has("age");
t.set("email", "test@mail.ru"); t.remove("email"); t.merge(other);

// Set (множество)
var s1 = #set{1, 2, 3};
s1.add(4); s1.remove(1); s1.has(3);
s1.isSubsetOf(#set{1,2,3,4});
s1.isSupersetOf(#set{1,2});
s1.symmetricDifference(#set{2,3,4});
s1.equals(#set{1,2,3});

// Stack / Queue / PriorityQueue
var stk = #stack{};  stk.push(10); stk.pop(); stk.peek();
var que = #queue{};  que.push(10); que.pop(); que.front();
var pq = #priorityqueue{};  pq.push("low", 0); pq.push("high", 10); pq.pop();

// Dictionary
var dic = #dictionary{};
dic.set("name", "Иван");  dic.get("name");  dic.has("name");  dic.remove("name");
dic.keys();  dic.values();  dic.size;     // size — свойство без ()
```

### Глобальные функции
```
type(42);           // 1 (int)
type("hello")       // 3 (string)
type(#[1,2])        // 5 (array)
typeName(42)        // "int"
typeName("hello")   // "string"

// Проверка типа:
if (type(val) == 3) print("это строка");
if (type(val) == 0) print("это null");

size(#[1,2,3]);     // 3
empty("");          // true
coalesce(null, 42); // 42
min(3, 7);          // 3
max(3, 7);          // 7
clamp(10, 0, 5);    // 5
format("Hello %s!", "World");  // "Hello World!"
eval("print('dynamic')");      // динамический код
inspect(#[1, 2, 3]);           // подробный вывод
```
