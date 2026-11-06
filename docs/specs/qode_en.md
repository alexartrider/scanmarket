## Script language syntax

Full documentation: `qt/docs/language.html`, `qt/docs/objects.html`, `qt/docs/functions.html`

### Keywords (both forms supported)
```
if/если, else/иначе, for/для, while/пока, do/цикл, return/возврат,
switch/выборпо, case/выбор, default/умолчание, break/прервать,
continue/продолжить, goto/перейти, function/функция, var/перем,
export/экспорт, class/класс, throw/исключение,
try/попытка, catch/перехват, finally/вконце,
and/и, or/или, not/не, uses/использовать, import/импорт, as/как
```

### Data types
```
Integer:      42, 0xFF, 0b1010, 0o755        — int64, hex/bin/oct
Float:        3.14, 1e10, .5                 — double
String:       "Hello", "val=\(x)"            — UTF-16, interpolation via \()
Date:         '2024-01-15', '14.30.00'       — in single quotes
Boolean:      true, false
Empty:        null
```

### Compile-time constants
```
__FILENAME__  — current file name
__LINE__      — current line number
__DATE__      — current date
__TIME__      — current time
```

### Escape sequences
```
\n       — newline
\t       — tab
\\       — backslash
\"       — double quote
\xNN     — hex character code (1-2 digits)
\uNNNN   — Unicode (4 hex digits)
\UNNNNNNNN — Unicode (8 hex digits)
\0NN     — octal code (1-3 digits)
```

### Multi-line strings
```
"Continuation of the string\
with a backslash"

"Concat: " "two strings"       // result: "Concat: two strings"
```

### Collections
```
Array:       #[1, 2, 3]                    — indexable list
Tuple:       #{"a": 1, "b": 2}             — immutable associative array
             #tuple{"a": 1}                — explicit creation
Set:         #{1, 2, 3}                    — unique elements
             #set{1, 2, 3}                 — explicit creation
Queue:       #queue{1, 2}                  — FIFO
Stack:       #stack{1, 2}                  — LIFO
Priority queue: #priorityqueue{}           — with priorities
Dictionary:  #dictionary{}                 — associative array

Static array: var arr[10] = [1,2,3];       — no #, declaration only
```

Automatic type detection for `#{...}`: pairs `"key": value` → tuple, plain values → set.

### Operators (precedence from lowest to highest)
```
1.  ,                                              — comma
2.  || / or / или                                  — logical OR
2.  && / and / и                                   — logical AND
3.  = += -= *= /= %= &= |= ^= <<= >>=             — assignment
4.  ? :                                            — ternary
5.  | ^ &                                          — bitwise: OR, XOR, AND
6.  < > <= >= == !=                                — comparison
7.  << >>                                          — bitwise shifts
8.  + -                                            — addition / subtraction
9.  * / %                                          — multiplication / division / remainder
10. **                                             — exponentiation (right-associative)
10. ! not ~ ++ --                                  — unary
11. . [] ::                                        — access: property, index, scope
```

### Functions
```
function add(a, b) { return a + b; }
function helper() export { ... }            — export after the argument list
var square = function(x) { return x * x; };
function greet(name = "world") { print("Hello, \(name)!"); }

// Default parameters — any expression:
function getData(path = file.getcwd()) { ... }
function calc(x = y + 1) { ... }
function apply(fn = function(x) { return x * 2; }) { ... }
```

### Export
```
function helper() export { ... }            — function is visible outside the module
var x = 0 export;                           — variable is visible outside the module
var y export;                               — exported variable without initialization
```

### Control structures
```
if (x > 0) { ... } else if (x == 0) { ... } else { ... }
for (var i = 0; i < 10; i++) { ... }
for (var item : arr) { ... }
for (var [key, value] : dict) { ... }     — destructuring
while (condition) { ... }
do { ... } while (condition);
switch (x) {
    case 1: ...;
    case 2: ...;
    default: ...;                         // or else:
}
try { ... } catch (e) { ... } finally { ... }
try { ... } catch (TypeError) { ... } catch (Error) { ... }  — multiple catch
```

### Classes
```
class Person {
    var name;
    var age;

    Person(name, age) {
        this.name = name;
        this.age = age;
    }

    function greet() {
        return "I am \(this.name), \(this.age) years old";
    }

    ~Person() { }                         — destructor
}

class Student : Person {                  — inheritance
    var university;
    Student(name, age, university) {
        this::Person(name, age);          — call to the base constructor
        this.university = university;
    }
}

var s = Student("Ivan", 20, "MSU");
print(s.greet());          // I am Ivan, 20 years old
print(s.university);       // MSU
```

### Modules
```
uses file;                                      — include a module
uses math;
import math as m;                               — with an alias

file.write("test.txt", "Hello");
math.sqrt(16);                                  — scope access
```

### Comments
```
// Single-line comment

/*
   Multi-line
   comment
*/
```

---

## Value methods (ScriptValue)

Available for any type:
```
v.size()              — size (string length, number of elements)
v.empty()             — true if empty
v.isnull()            — null check
v.isbool() / v.isint() / v.isdouble() / v.isnumber() / v.isstring()
v.isdatetime() / v.isarray() / v.istuple() / v.isset()
v.isobject() / v.iscontainer() / v.iscode() / v.isclass()
v.clone()             — deep copy
v.type()              — numeric type code (0..11)
v.typename()          — type name: "INT", "STRING", "ARRAY"...
v.json() / v.json(true)  — JSON serialization
v.pretty()            — pretty-printed output with indentation
v.hash()              — hash value
v.asarray()           — convert to array
v.asbytearray()       — convert to byte array
v.astuple()           — convert to tuple
v.asset()             — convert to set
v.concat(other)       — union (modifies the original value)
v.difference(other)   — set difference (modifies the original value)
v.intersection(other) — intersection (modifies the original value)
v.subtract(other)     — subtraction (modifies the original value)
v.forEach(func)       — call a function for each element
```

---

## Global functions

### Output and logging
```
print(args...)          — print to console with a newline
trace(args...)          — TRACE-level output
error(args...)          — ERROR-level output
inspect(val)            — detailed value inspection
dump(val)               — value dump
help()                  — help on functions
```

### Types and introspection
```
type(val)               — numeric type code: 0=null, 1=int, 2=double, 3=string,
                          4=datetime, 5=array, 6=tuple, 7=set, 10=object
typeName(val)           — type name as a string (lowercase): "null", "int", "string"...
size(val)               — size (string length, number of elements)
empty(val)              — true if empty
propertyNames(obj)      — property names of an object
exists(name)            — whether a variable exists
propertyExists(obj, name) — whether an object property exists
methodExists(obj, name)   — whether an object method exists
hash(val)               — hash value
```

### Aggregate functions
```
sum(arr)                — sum of elements
product(arr)            — product
avg(arr) / mean(arr)    — arithmetic mean
max(a, b)               — maximum of two values
min(a, b)               — minimum of two values
clamp(val, lo, hi)      — clamp to a range: min(max(val, lo), hi)
median(arr)             — median
sumsq(arr)              — sum of squares
```

### Working with collections
```
toarray(val)            — convert to array
push(arr, val)          — append an element
pop(arr)                — remove the last element
clear(arr)              — clear a collection
sorted(set)             — sorting (returns a SET, not an array!)
reversed(arr)           — reverse (returns an ARRAY)
range(start, [end], [step]) — generate a numeric range (returns a SET)
foreach(arr, func)      — call a function for each element
map(arr, func)          — transform each element
filter(arr, func)       — filter by condition
reduce(arr, func, init) — fold (accumulator)
```

### String formatting (printf-style)
```
%s  — string         %d  — integer        %f  — floating-point
%e  — exponential    %g  — shortest       %x  — hex
%o  — octal          %c  — character      %%  — literal %

format("Hello %s, value: %d", "World", 42)  // "Hello World, value: 42"
format("Pi = %.2f", 3.14159)                // "Pi = 3.14"
```

### Scopes
```
globals()               — all global variables
scope()                 — current scope
scopeflat()             — flat list of variables
```

### JSON (module json)
```
json.parse(string)                — parse a JSON string → tuple (object) or array
json.stringify(value, [pretty])   — value → JSON string
json.stringify(value, true, [indent]) — pretty-printed output with indentation (4 spaces by default)
json.validate(string)             — JSON validity check → true/false
```
JSON ↔ Script type mapping:
| JSON | Script |
|------|--------|
| object `{}` | tuple `#{"key": val}` |
| array `[]` | array `#[...]` |
| string | string |
| number (int) | int |
| number (float) | double |
| true/false | int (1/0) — boolean values are stored as int |
| null | null |

### XML (module xml)
```
xml.parse(string)        — parse an XML string → XmlDocument
xml.load(path)           — load XML from a file → XmlDocument
xml.create(rootName)     — create a new document with a root element
```

XmlDocument methods:
```
doc.child(name)          — first child element by name
doc.children()           — all child elements of the root (an array of XmlNode)
doc.print()              — serialize to a string (with indentation)
doc.save(path, [indent]) — save to a file (indent=true by default)
doc.set_root(name)       — add a root element → XmlNode
```

XmlNode methods:
```
node.name()              — element name
node.value()             — value of the value attribute (or "")
node.set_value(val)      — set the value
node.text()              — text content of the element
node.set_text(val)       — set the text content
node.attribute(name)     — attribute value by name (or null)
node.set_attribute(name, val) — set/create an attribute
node.child(name)         — first child element by name
node.children()          — all child elements (an array of XmlNode)
node.parent()            — parent element
node.next_sibling()      — next sibling element
node.prev_sibling()      — previous sibling element
node.append_child(name)  — append a child element → XmlNode
node.remove_child(name)  — remove a child element by name
node.attributes()        — all attributes (an array of tuples {name, value})
node.empty()             — true if the element is empty
node.print()             — serialize the subtree to a string
```

### Code execution
```
eval(code)              — execute a string as code
execute(path)           — execute a file
loadModule(path)        — load a module
loadPlugin(path, [alias]) — load a plugin by the path to a .dll
```

### Other
```
coalesce(a, b, ...)     — first non-null value
assert(cond, [msg])     — assertion check
version()               — engine version
tojson(val)             — alias of json.stringify
fromjson(str)           — alias of json.parse
__FILENAME__            — current file
__LINE__                — current line
```

---

## Module str

### Information
```
str.len(s)              — number of characters
str.empty(s)            — true if the string is empty
str.toString(val)       — convert to string
str.toInt(s)            — convert to integer
str.toDouble(s)         — convert to floating point number
str.ord(s)              — code of the first character
```

### Search and checking
```
str.pos(s, sub)         — position of the first occurrence or -1
str.rpos(s, sub)        — position of the last occurrence or -1
str.count(s, sub)       — number of occurrences of the substring
str.startswith(s, prefix) — whether the string starts with prefix
str.endswith(s, suffix)   — whether the string ends with suffix
str.findany(s, chars)   — position of the first character from the set chars
str.findnot(s, chars)   — position of the first character NOT in the set chars
```

### Extraction
```
str.sub(s, start, [len])    — substring. Negative indices count from the end
str.first(s, [count])       — first count characters (default 1)
str.last(s, [count])        — last count characters
str.left(s, count)          — count characters from the start
str.right(s, count)         — count characters from the end
str.mid(s, start, len)      — substring at position start of length len
```

### Modification
```
str.replace(s, from, to)    — replace ALL occurrences
str.remove(s, sub)          — remove ALL occurrences of the substring
str.insert(s, pos, sub)     — insert the substring at position pos
str.reverse(s)              — reverse the string
str.quoted(s)               — wrap in quotes, escaping the inner ones
str.repeat(s, count)        — repeat the string count times
```

### Case
```
str.upper(s) / str.lower(s)     — case
str.swapcase(s)                 — swap the case of each character
str.capitalize(s)               — first letter uppercase
str.title(s)                    — uppercase the first letter of each word
str.iequals(s1, s2)             — case-insensitive comparison
```

### Trimming
```
str.trim(s)                     — whitespace from both ends
str.ltrim(s) / str.rtrim(s)    — whitespace from the left / right
str.strip(s, chars)             — the specified characters from both ends
str.lstrip(s, chars)            — the specified characters from the left
str.rstrip(s, chars)            — the specified characters from the right
```

### Padding and alignment
```
str.pad(s, width, charCode)     — padding on the right. charCode is an int character code!
str.zfill(s, width)             — padding with zeros on the left
str.center(s, width, [fill])    — centering
str.ljust(s, width, [fill])     — left alignment
str.rjust(s, width, [fill])     — right alignment
```

### Conversions
```
str.itoa(n)                     — integer → string
str.atof(s)                     — string → floating point number
str.atoi(s)                     — string → integer
str.hex(n)                      — to hex (with 0x prefix)
str.bin(n)                      — to binary (with 0b prefix)
str.oct(n)                      — to octal (with 0o prefix)
str.fromCharCode(code)          — code → string
```

### Static (global)
```
str.len(s)                  // 5
str.join("-", "a", "b", "c")  // "a-b-c"
str.toInt("42")             // 42
str.toDouble("3.14")        // 3.14
```

---

## String methods (instance)

```
s.clear()                       — clear the string (mutates)
s.upper() / s.lower()           — case
s.trim() / s.ltrim() / s.rtrim() — trim whitespace
s.pos(needle)                   — index of the first occurrence (-1)
s.contains(needle)              — true if found (the argument must be a string, otherwise false)
s.split(sep)                    — split into an array
s.splitlines()                  — split by line breaks
s.replace(from, to)             — replace ALL occurrences
s.repeat(n)                     — repeat n times
s.pad(width, char, side)        — side: 0=right, 1=left, 2=center
s.zfill(width)                  — padding with zeros on the left
s.reverse()                     — reverse
s.sub(start, len)               — substring
s.left(count) / s.right(count)  — left/right characters
s.mid(start, len)               — substring at a position
s.first([count]) / s.last([count]) — first/last N characters
s.chopped(n)                    — without the last N characters
s.capitalize()                  — first letter uppercase, the rest lowercase
s.title()                       — uppercase the first letter of each word
s.count(needle)                 — number of occurrences of the substring
s.startswith(prefix) / s.endswith(suffix)
s.find_first_of(chars)          — first character from the set
s.find_last_of(chars)           — last character from the set
s.find_first_not_of(chars)      — first character NOT in the set
s.find_last_not_of(chars)       — last character NOT in the set
s.comparenocase(other)          — case-insensitive comparison
s.isalnum() / s.isalpha() / s.isdigit()
s.islower() / s.isupper() / s.isspace()
s.regexmatch(pattern)           — true if the whole string matches
s.regexsearch(pattern)          — true if there is a partial match
s.regexreplace(pattern, repl)   — replace by regex
s.regexsplit(pattern)           — split by regex
s.regexfindall(pattern)         — all matches
s.codepointcount()              — number of codepoints
s.codepointat(i)                — Unicode character code
s.isvalidutf16()                — UTF-16 validation
s.tocodepoints()                — array of character codes
s.extractnumbers()              — extract numbers
s.trimtrailingslashes()         — removes trailing /
s.toArray()                     — split by comma into an array
s.tobytes()                     — to ByteArray
s.tonumber()                    — convert to a number
```

---

## Array methods

```
arr.clear()                     — clear
arr.add(v1, v2, ...)            — append to the end
arr.push(v1, v2, ...)           — alias of add
arr.pop()                       — remove and return the last element
arr.insert(index, val)          — insert at index
arr.removeAt(index)             — remove at index
arr.remove(val)                 — remove ALL occurrences
arr.removeAll(val)              — remove all occurrences
arr.swap(i, j)                  — swap elements
arr.clone()                     — deep copy
arr.size()                      — number of elements
arr.empty()                     — true if empty
arr.sort() / arr.sort(func)     — sort (default or with a function)
arr.reverse()                   — reverse (mutates)
arr.reversed()                  — new sorted array (does not mutate)
arr.unique()                    — remove duplicates (after sorting!)
arr.contains(val)               — true if found
arr.indexOf(val)                — index of the first occurrence (-1)
arr.lastIndexOf(val)            — index of the last occurrence
arr.includes(val)               — true if present
arr.count(val)                  — number of occurrences
arr.find(func)                  — first matching element
arr.every(func)                 — true if ALL satisfy the condition
arr.some(func)                  — true if AT LEAST ONE
arr.forEach(func)               — for each element
arr.map(func) / arr.mapped(func)  — new array with transformations
arr.filter(func) / arr.filtered(func) — new array after filtering
arr.reduce(func, init)          — fold
arr.sum()                       — sum of elements
arr.average()                   — average value
arr.first() / arr.last()        — first / last
arr.min() / arr.max()           — minimum / maximum
arr.sliced(start, end)          — part of the array [start, end)
arr.mid(pos) / arr.mid(pos, n)  — slice from position
arr.joined(sep)                 — join into a string
arr.toString()                  — "[3, 1, 4, 1, 5]"
arr.flattened()                 — new flat array
arr.flatten()                   — flatten in place
arr.grouped(func)               — group by key
arr.setto(val)                  — fill all elements
arr.shuffle()                   — shuffle
arr.tuple()                     — convert to tuple
arr.set()                       — convert to set
arr.sort(func)                  — custom sort
```

---

## Set methods

```
set.clear()                     — clear
set.contains(val) / set.has(val) — true if the element is present
set.add(val)                    — add
set.remove(val)                 — remove
set.isSubsetOf(other)           — true if it is a subset
set.isSupersetOf(other)         — true if it is a superset
set.symmetricDifference(other)  — only in one of the two (modifies the original value)
set.equals(other)               — set equality
set.every(func) / set.some(func) — condition check
set.reduce(func, init)          — fold
set.difference(other)           — difference (modifies the original value)
set.intersection(other)         — intersection (modifies the original value)
```

---

## Tuple methods

```
t.clear()                       — clear
t.contains(key)                 — true if the key is present (same as has)
t.keys()                        — array of keys
t.values()                      — array of values
t.has(key)                      — true if the key exists
t.get(key)                      — value by key (null if missing)
t.set(key, val)                 — set key=value
t.remove(key)                   — remove by key
t.merge(other)                  — merge (modifies the original value)
t.every(func) / t.some(func)    — condition check
t.reduce(func, init)            — fold: func(acc, key, value)
```

---

## Date/time methods (instance)

```
dt.year()                       — year
dt.month()                      — month (1-12)
dt.day()                        — day (1-31)
dt.hour()                       — hour (0-23)
dt.minute()                     — minute (0-59)
dt.second()                     — second (0-59)
dt.millisecond()                — millisecond (0-999)
dt.weekday()                    — day of week (1-7, 1=Mon)
dt.addday(n) / dt.addmonth(n) / dt.addyear(n)
dt.addhour(n) / dt.addminute(n) / dt.addsecond(n)
```

---

## Module datetime

### Current time
```
datetime.now()                  — current date/time (local)
datetime.utcnow()               — current UTC
datetime.timezone()             — string representation of the time zone
datetime.timezoneoffset()       — UTC offset in seconds
```

### Creating a date
```
datetime.makedatetime(y, m, d, [H, M, S]) — date/time from components
datetime.fromtimestamp(ts)      — from Unix timestamp
datetime.parse(str, fmt)        — parse a string by format
```

### Formatting
```
datetime.strftime(dt, fmt)      — date → string by format
datetime.strptime(str, fmt)     — string → date by format
datetime.datetostring(dt)       — date as a string
datetime.timetostring(dt)       — time as a string
datetime.datetimetostring(dt)   — date+time as a string
```

### Arithmetic
```
datetime.addday(dt, n) / datetime.addmonth(dt, n) / datetime.addyear(dt, n)
datetime.addhour(dt, n) / datetime.addminute(dt, n) / datetime.addsecond(dt, n)
datetime.subday(dt, n)          — -n days
```

### Difference between dates
```
datetime.daysdiff(d1, d2)       — difference in days
datetime.monthsdiff(d1, d2)     — difference in months
datetime.hoursdiff(d1, d2)      — difference in hours
datetime.minutesdiff(d1, d2)    — difference in minutes
datetime.secondsdiff(d1, d2)    — difference in seconds
datetime.interval(d1, d2)       — string representation of the interval
```

### Date components
```
datetime.parts(dt)              — {year, month, day, hour, minute, second}
datetime.weekday(dt)            — day of week (0=Mon)
datetime.weekdayname(dt)        — weekday name
datetime.monthname(dt)          — month name
datetime.yearday(dt)            — day of the year
datetime.weeknumber(dt)         — week number
datetime.quarter(dt)            — quarter (1-4)
datetime.timestamp(dt)          — Unix timestamp
```

### Start/end of periods
```
datetime.startofday(dt) / datetime.endofday(dt)
datetime.startofweek(dt) / datetime.endofweek(dt)
datetime.startofmonth(dt) / datetime.endofmonth(dt)
datetime.startofquarter(dt) / datetime.endofquarter(dt)
```

### strftime format specifiers
```
%Y  — year (4 digits)       %m  — month (01-12)     %d  — day (01-31)
%H  — hour (00-23)         %I  — hour (01-12)       %M  — minute (00-59)
%S  — second (00-59)     %a  — short weekday %A  — full weekday
%b  — short month        %B  — full month       %p  — AM/PM
%j  — day of year           %w  — day of week (0-6)  %W  — week of year
%U  — week of year (Sunday)  %x  — locale date  %X  — locale time
%%  — literal %
```

---

## Module math

### Constants
```
math.pi            — 3.14159...        math.e            — 2.71828...
math.tau           — 6.28318... (2π)   math.phi          — 1.61803... (golden ratio)
math.sqrt2         — 1.41421... (√2)   math.inf          — ∞
math.nan           — NaN               math.epsilon      — 2.22e-16
math.INT64_MAX     — 9223372036854775807
math.INT32_MAX, math.SIZE_MAX, math.max_double, math.min_double
math.ln2, math.ln10, math.log2e, math.log10e, math.sqrt1_2
```

### Trigonometry
```
math.sin(x) / math.cos(x) / math.tan(x)
math.asin(x) / math.acos(x) / math.atan(x)
math.atan2(y, x)        — arctan(y/x) taking the quadrant into account
math.sinh/cosh/tanh(x)  — hyperbolic functions
math.asinh/acosh/atanh(x) — inverse hyperbolic functions
math.degrees(x)         — radians → degrees
math.radians(x)         — degrees → radians
```

### Powers, roots, logarithms
```
math.sqrt(x) / math.cbrt(x)
math.pow(x, y)          — x to the power y
math.hypot(x, y)        — √(x² + y²)
math.exp(x)             — e^x
math.log(x)             — natural logarithm
math.log10(x) / math.log2(x)
math.logx(x, base)      — to an arbitrary base
```

### Rounding and comparison
```
math.abs(x) / math.ceil(x) / math.floor(x) / math.trunc(x)
math.round(x, [prec])   — rounding (default prec=0.01)
math.sign(x)            — sign: -1, 0, 1
math.fmax(a, b) / math.fmin(a, b)
math.clamp(x, min, max) — clamp to a range
math.isclose(a, b, [rt], [at]) — float comparison
```

### Statistics
```
math.fsum(arr)          — sum of elements
math.prod(arr)          — product
math.mean(arr)          — arithmetic mean
math.median(arr)        — median
math.variance(arr)      — variance (population)
math.stddev(arr)        — standard deviation
math.mode(arr)          — mode
math.pctchange(old, new) — percentage change
math.gcd(a, b)          — GCD
math.lcm(a, b)          — LCM
math.factorial(n)       — factorial
```

### Random numbers
```
math.rand()                 — [0.0, 1.0)
math.randint(min, [max])    — random integer [min, max]
```

### Financial
```
math.pv(rate, pmt, periods)       — present value of an annuity
math.fv(rate, pmt, periods)       — future value of an annuity
math.pmt(rate, principal, periods) — loan payment
math.npv(rate, cf1, ...)          — net present value
```

---

## Module file

### Constants
```
file.ENC_UTF16_LE / file.ENC_UTF16_BE / file.ENC_UTF8_BOM
file.ENC_UTF8_NO_BOM / file.ENC_CP1251 / file.ENC_UNKNOWN
file.sep          — primary separator (\ on Windows)
file.altsep       — alternative separator (/ on Windows)
file.pathsep      — PATH separator (; / :)
```

### Existence and type checks
```
file.exists(path) / file.isfile(path) / file.isdir(path) / file.issymlink(path)
```

### File information
```
file.size(path)             — size in bytes
file.mtime(path)            — modification time
file.ctime(path)            — creation time
file.atime(path)            — access time
file.isreadonly(path)       — "Read-only" attribute
file.ishidden(path)         — "Hidden" attribute
```

### Reading
```
file.read(path, [enc])      — reads as a string (encoding auto-detected; BOM is skipped)
file.readlines(path)        — array of lines (by "\n", strips "\r"; empty lines are kept;
                              a trailing newline does not produce an empty tail; empty file -> [])
file.readmeta(path)         — #{text, enc, bom}: text + encoding (file.ENC_*) + BOM presence
file.readbytes(path)        — array of int64 values (each element is a byte)
```

### Writing
```
file.write(path, text, [enc])     — writes a string (UTF-16 LE by default)
file.writebytes(path, data)       — writes a byte array or ByteArray
file.append(path, text, [enc])    — appends to the end of the file
```

### File operations
```
file.copy(src, dst) / file.move(src, dst) / file.remove(path)
file.touch(path)            — updates mtime (or creates the file)
```

### Directories
```
file.mkdir(path)                    — creates a directory
file.mkdirrecursive(path)           — creates with all intermediate directories
file.rmdir(path)                    — removes an empty directory
file.rmdirrecursive(path)           — removes including contents (!)
file.dir([path, [pattern]])         — list of files/folders
file.dirrecursive([path, [pattern]]) — recursive traversal
```

### Path handling
```
file.basename(path)         — file name with extension
file.filename(path)         — file name without extension
file.dirname(path)          — path to the parent directory
file.extension(path)        — extension (with a dot)
file.absolute(path)         — absolute path
file.relative(path, base)   — relative path from base
file.join(p1, p2, ...)      — safe path joining
file.normalize(path)        — normalization (removes .. and extra /)
file.split(path)            — splits into (dir, file)
file.splitext(path)         — splits into (name, ext)
file.expanduser(path)       — replaces ~ with the home directory
file.realpath(path)         — canonical path
file.samefile(p1, p2)       — checks for the same file
```

### System paths and environment
```
file.homedir()              — home directory
file.tempdir()              — temporary directory
file.tempfile()             — temporary file
file.getcwd()               — current working directory
file.chdir(path)            — changes the working directory
file.getenv(name)           — environment variable
file.setenv(name, val)      — sets an environment variable
file.environ()              — all environment variables
file.space(path)            — disk information
```

---

## Module ByteArray

### Creation
```
var ba = ByteArray()                                — new empty one
var ba = ByteArray.fromString("Hello", ByteArray.encode_utf8)
var ba = ByteArray.fromHex("48656C6C6F")
var ba = ByteArray.fromBase64("SGVsbG8=")
```

### Encoding constants
```
ByteArray.encode_utf8 / ByteArray.encode_cp1251 / ByteArray.encode_cp866
ByteArray.encode_hex / ByteArray.encode_base64
```

### Properties
```
ba.size / ba.length / ba.empty / ba[i]
```

### Methods
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

## Module Log

### Properties
```
Log.IsWindowsTerminal     — whether running in Windows Terminal
Log.console               — console window visibility (bool, read/write)
Log.filePrefix            — log file name prefix
Log.remoteFilePath        — path to the remote log file
Log.localFilePath         — path to the local log file
Log.writeToRemote         — write to the remote file
Log.writeToLocal          — write to the local file
```

### Methods
```
Log.rotate()              — log file rotation
Log.print(args...)        — output to the console
Log.trace(args...)        — tracing (TRACE level)
Log.error(args...)        — error (ERROR level)
Log.format(args...)       — formatting without output
Log.consoleInfo()         — console state snapshot: attached, visible,
                            stdoutIsConsole, stderrIsConsole, outputRedirected,
                            outputCodePage, inputCodePage, stdoutMode, stderrMode,
                            vtProcessing, processedOutput, ansiColorsEnabled,
                            lastError, refreshSucceeded
Log.refreshConsole()      — re-check handles and reapply output modes
                            (after child processes). No FreeConsole/AllocConsole
```

---

## Module system

### Process execution
```
system.system(cmd)                  — synchronous command execution
system.systemex(cmd, [timeout])     — with a timeout. Returns {success, code, killed}
system.systemasync(cmd, [workDir], [timeout], [options])
                                    — asynchronous. Returns a Process object.
                                      options = #{"console": "inherit"|"new"|"detached"}:
                                      "inherit" — shared console (default);
                                      "new"     — separate console (CREATE_NEW_CONSOLE);
                                      "detached" — no parent console (DETACHED_PROCESS)
```

### Process object
```
p.isReady       — process has finished
p.runtime       — execution time (ms)
p.result        — result {success, code, killed}
p.kill()        — kills the process
```

### Environment
```
system.env()                        — environment variables
system.getcommandline()             — command line arguments: app/basename/dirname/filename,
                                      argv0, raw (all in order), args (non-flags), count,
                                      flags (tuple; a repeat keeps the first value),
                                      parsed (ordered tokens: flag/value/pos/end for "--")
```

### Profiling
```
system.sleep(ms)                    — pause in milliseconds
system.gettickcount()               — current time (ms) for profiling
system.timeit(func, args...)        — measures function execution time
system.benchmark(func, n)           — benchmark: n function calls
```

### System information
```
system.computername()               — computer name
system.username()                   — user name
system.cpuid()                      — CPU identifier
system.vendor()                     — CPU vendor
system.id()                         — unique identifier
```

### Power management
```
system.shutdown() / system.reboot() / system.logoff()
```

### Sound
```
system.beep(freq, duration)         — beep
system.messagebeep(type)            — system sound
```

### Input/output and control
```
system.write(text)                  — writes without a newline
system.writeln(text)                — writes with a newline
system.exit(code)                   — exits with a code
system.abort()                      — aborts abruptly
```

---

## Geometric primitives

### QodePoint
```
var p = QodePoint(10, 20);

Properties: x, y (read/write)

Methods:
p.add(p|s|x,y)             — addition (returns a QodePoint)
p.subtract(p|s|x,y)        — subtraction
p.scale(factor)             — scaling
p.offset(s|x,y)             — offset (alias for add)
p.setlocation(x,y)          — sets the coordinates
p.negate() / p.abs()        — negation / absolute value
p.min(p|x,y) / p.max(p|x,y) — component-wise min/max
p.clamp(min, max)           — clamps to a range
p.rotate(angle, center?)    — rotation (radians)
p.lerp(target, t)           — linear interpolation (t: 0..1)
p.distance(p|x,y)           — distance to a point
p.length()                  — vector length from (0,0)
p.angle(p|x,y)              — angle to a point (atan2)
p.normalize()               — normalization (length = 1)
p.ptincircle(center, radius) — checks if inside a circle
p.equals(p) / p.iszero() / p.isempty()
p.clone() / p.toarray() / p.toQodeSize()
```

### QodeSize
```
var s = QodeSize(100, 200);

Properties: cx, cy (read/write)

Methods:
s.add(s|cx,cy) / s.subtract(s|cx,cy) / s.scale(factor)
s.swap()                    — swaps cx/cy
s.fit(target)               — scaling preserving aspect ratio
s.expand(s) / s.reduce(s)  — component-wise max/min
s.aspect()                  — aspect ratio (cx/cy)
s.area() / s.maxside() / s.minside()
s.equals(s) / s.iszero() / s.clone()
s.toarray() / s.toQodePoint()
```

### QodeRect
```
var r = QodeRect(0, 0, 100, 200);           — (left, top, right, bottom)
var r = QodeRect(QodePoint, QodeSize);
var r = QodeRect(QodePoint1, QodePoint2);

Properties: left, top, right, bottom, width, height,
          topleft, bottomright, location, QodeSize

Transformation methods:
r.move(p|x,y) / r.offset(p|s|x,y)
r.inflate(s|dx,dy|d) / r.shrink(s|dx,dy|d)
r.scale(sx, [sy]) / r.normalize() / r.round()

Geometric operations:
r.union(r) / r.intersect(r) / r.fit(target) / r.split(cols, rows)

Queries:
r.contains(p|x,y) / r.containsQodeRect(r) / r.intersects(r)
r.center() / r.aspect() / r.area()
r.isempty() / r.iszero() / r.equals(r) / r.clone()
r.setQodeRect(l,t,r,b)
```

**Important:** `add`, `subtract`, `scale`, `inflate` **mutate** the object (they return `shared_from_this()`).

---

## qt modules (QT-specific)

### QT modules
```
qt.XlsxDocument() / qt.QXlsxDocument()  — Excel document (XLSX)
  see also qt/docs/xlsx.html
```

---

## Plugins

Plugins are loaded via `loadPlugin`. `uses` is only for built-in modules.
```
loadPlugin("archive7zip");              // load by name
loadPlugin("archive7zip", "zip");       // with an alias
```

### Available plugins
| Plugin | Description |
|--------|----------|
| `archive7zip` | 7z/ZIP/TAR/GZIP archives (via 7z.exe) |
| `clipboard` | Windows clipboard — text and images |
| `comport` | COM ports |
| `crypto` | Cryptography |
| `dbf` | DBF reading/writing |
| `ftpclient` | FTP client |
| `http` | HTTP/HTTPS client and server |
| `websocket` | WebSocket client |
| `imap` | IMAP client |
| `inicsv` | INI and CSV files |
| `max` | MAX Messenger bot (Bot API, Long Polling) |
| `registry` | Windows registry |
| `screen` | Screenshots, screen capture |
| `smtp` | SMTP sending |
| `tcp` | TCP client/server |
| `udp` | UDP client/server |

Detailed reference: `qt/docs/plugins.html`, `qt/docs/plugin_development.html`

---

## http module

### Creation
```
loadPlugin("plugins/http.dll");
var http = HttpClient();
```

### Requests
```
http.get(url)                                    — GET request
http.post(url, [body], [contentType])            — POST
http.put(url, [body], [contentType])             — PUT
http.del(url)                                    — DELETE
http.patch(url, [body], [contentType])           — PATCH
http.head(url)                                   — HEAD
http.request(method, url, [body], [contentType]) — arbitrary method
```

### File download and upload
```
http.download(url, filePath)                     — download to disk
http.upload(url, filePath, [fieldName])          — multipart/form-data upload
```

### Headers and authentication
```
http.setHeader(name, value)                      — request header
http.clearHeaders()                              — clear headers + auth
http.setBasicAuth(user, pass)                    — Basic Auth
http.setBearerAuth(token)                        — Bearer Token
http.setUserAgent(ua)                            — User-Agent
```

### Configuration
```
http.setTimeout(ms)                              — timeout (ms)
http.setFollowRedirects(bool)                    — auto-redirects (default true)
http.setProxy(host, port)                        — HTTP proxy
http.setVerifySsl(bool)                          — verify SSL certificates
```

### Result
```
http.status()                                    — HTTP status (200, 404...)
http.statusText()                                — status text (OK, Not Found)
http.getResponse()                               — body as a string
http.getResponseBytes()                          — body as a ByteArray
http.getHeader(name)                             — response header
http.getResponseHeaders()                        — all response headers
http.lastError()                                 — last error
```

### Utilities
```
http.urlEncode(str)                              — URL encoding
http.urlDecode(str)                              — URL decoding
http.getMimeType(filename)                       — MIME type by extension
http.connect(host, port, [ssl])                  — manual connection
http.disconnect()                                — disconnect
http.isconnected()                               — connection check
```

### Example
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

## http module (HTTP server)

### Creation
```
var server = HttpServer();
```

### Server methods
```
server.listen(port)                                   — start listening on a port
server.stop()                                         — stop the server
server.islistening()                                  — listening state check
server.port()                                         — current port number
server.process([timeout_ms])                          — process a request (returns tuple/null)
server.respond(socketId, responseTuple)               — send a response and close the connection
server.lastError()                                    — last error
```

### process(timeout_ms)
Waits for an incoming request for timeout_ms (50 ms by default).
Returns the request tuple, or null if there are no requests.

Request tuple:
```
req.method       — HTTP method (GET, POST, ...)
req.path         — request path (/api/data)
req.query        — query string (q=test&page=1)
req.body         — request body
req.headers      — request headers (tuple)
req.port         — server port
req.socket       — connection identifier (for respond)
```

### respond(socketId, responseTuple)
Sends an HTTP response and closes the connection.

Response tuple:
```
response.status      — HTTP status (200 by default)
response.statusText  — status text ("OK" by default)
response.body        — response body
response.headers     — response headers (tuple)
```

### Example
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

## websocket module (WebSocket client)

### Creation
```
loadPlugin("plugins/websocket.dll");
var ws = WebSocket();
```

### Connection
```
ws.connect(url)     — ws:// or wss://. Returns bool
ws.disconnect()     — disconnect without a close frame
ws.isconnected()    — connection check
ws.close()          — graceful close (close frame)
```

### Messages
```
ws.send(text)           — send text. Returns bool
ws.sendBinary(data)     — send a ByteArray or a string. Returns bool
ws.recv()               — receive text (string|null)
ws.recvBinary()         — receive ByteArray (ByteArray|null)
ws.ping()               — send a ping frame. Returns bool
```

### Message queue
```
ws.hasMessage()         — whether messages are available. Returns bool
ws.messageCount()       — number of messages in the queue. Returns int
ws.clearMessages()      — clear the queue. Returns bool
```

### Configuration
```
ws.setTimeout([ms])     — read timeout (ms). Getter with no arguments
ws.lastError()          — last error (string|null)
```

### Example
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

## ssh module (SSH/SCP/SFTP)

### Creation
```
var session = ssh.connect();           — creates a session object
```

### Information
```
ssh.version()                          — libssh2 version
```

### Session methods (session)

#### Connection
```
session.connect(host, port, user, pass) — connect over SSH (returns bool)
session.disconnect()                   — disconnect
session.isconnected()                  — connection check
session.last_error()                   — last error
```

#### Command execution
```
session.exec(command)                  — execute a command (returns stdout+stderr)
```

#### SCP (file transfer)
```
session.scp_send(remote_path, data)    — send data to a remote file
session.scp_recv(remote_path)          — download a remote file (returns a string)
```

#### SFTP (file system)
```
session.sftp_init()                    — initialize an SFTP session (returns bool)
session.sftp_open(path, mode)          — open a file (mode: "r", "w", "a", "rb", "wb")
session.sftp_read(handle, max_bytes)   — read data from a file
session.sftp_write(handle, data)       — write data to a file
session.sftp_close(handle)             — close a file
session.sftp_readdir(path)             — list files in a directory
session.sftp_mkdir(path)               — create a directory
session.sftp_rmdir(path)               — remove a directory
session.sftp_unlink(path)              — remove a file
session.sftp_rename(old_path, new_path)— rename a file
session.sftp_stat(path)                — file info {size, mode, mtime, atime, isdir}
```

### Example
```
var session = ssh.connect();
if (session.connect("192.168.1.1", 22, "user", "pass")) {
    // Execute a command
    var result = session.exec("ls -la");
    print(result);
    
    // SFTP: write a file
    var h = session.sftp_open("/tmp/test.txt", "w");
    session.sftp_write(h, "Hello!");
    session.sftp_close(h);
    
    // SFTP: read a file
    var h2 = session.sftp_open("/tmp/test.txt", "r");
    var content = session.sftp_read(h2, 1024);
    print(content);
    session.sftp_close(h2);
    
    // SCP: send a file
    session.scp_send("/tmp/remote.txt", "data to send");
    
    session.disconnect();
}
```

---

## snmp module (SNMP monitoring)

### Creation
```
var s = snmp.open();                   — creates a session object
```

### Session methods

#### Connection
```
s.open(host, port, community, version?) — UDP connection (version: "v1"/"v2c", default "v2c")
s.close()                               — close the socket
s.isopen()                              — 1 if open
s.timeout(ms?)                          — timeout getter/setter (ms, default 3000)
s.last_error()                          — last error
```

#### Requests
```
s.get(oid...)                           — SNMP GET (one or more OIDs)
s.getnext(oid...)                       — SNMP GETNEXT
s.getbulk(non_reps, max_reps, oid...)   — SNMP GETBULK (v2c only)
s.set(oid, value, type?)                — SNMP SET (type: "int"/"octet"/"counter"/"gauge"/"timeticks"/"ip"/"null")
s.walk(root_oid, max?)                  — GETNEXT traversal from root_oid (returns an array)
```

### Response
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

### Example
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

## sqlite module (native SQLite)

### Creation
```
var db = sqlite.open("data.db");     — open or create a database file
var mem = sqlite.memory();            — in-memory database
sqlite.version();                     — SQLite version
```

### Database methods
```
db.exec(sql, params?)                 — run SQL without fetching results
db.execute(sql, params?)              — alias of exec
db.query(sql, params?)                — SELECT → array of tuples
db.scalar(sql, params?)               — first field of the first row
db.begin() / db.commit()              — transaction
db.rollback()                         — roll back a transaction
db.changes()                          — number of changed rows
db.last_insert_rowid()                — ID of the last inserted row
db.isopen() / db.close()              — database state and closing
db.last_error()                       — last error message
```

### Parameters
```
db.exec("insert into t(value) values (?)", #["text"]);
db.exec("insert into t(value) values (:value)", #{":value": "text"});
```

### Types
```
NULL    → null
INTEGER → integer
REAL    → real number
TEXT    → string
BLOB    → array of numeric bytes
```

### Example
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

## inicsv module (INI/CSV)

Loading:
```
loadPlugin("plugins/inicsv.dll");
```

### Encodings
```
"utf8"      — UTF-8 without BOM
"utf8bom"   — UTF-8 with BOM
"utf16"     — UTF-16 LE
"cp1251"    — Windows-1251 (default for new files)
"auto"      — keep the encoding of an existing file
```
Reading detects the encoding automatically (BOM + heuristics). If no encoding is specified on
write, or `"auto"` is passed and the file already exists, its encoding is kept; for a new file — `cp1251`.

### CSV

```
csvRead(filename, fields, [encoding|separator], [separator])  — read into an array of tuples
csvWrite(filename, fields, data, [encoding], [separator])     — write, returns 1/0
csvRowCount(filename)                                         — number of data rows (excluding the header)
```

- `fields` — a string `"a;b;c"` or an array `#["a","b","c"]` (expected columns);
- the default separator is `";"`; passed as the 4th argument, or as the 3rd instead of the encoding;
- the CSV header — the first row of the file (csvRead) or `fields` (csvWrite);
- csvWrite accepts `data` as an array (or tuple) of tuples/arrays of strings; rows of non-tabular types are skipped;
- values: an empty string → `null`, integers → `int`, floating-point numbers → `double`, `true/yes` → `1`, `false/no` → `0`, anything else — a string;
- missing expected fields are filled with `null`;
- RFC parsing: quotes and separators inside fields, multi-line fields, CRLF/LF/CR, BOM, `""` — an escaped quote;
- on write, values containing separators, quotes, leading/trailing whitespace or line breaks are wrapped in `"` (`"` → `""`), rows are separated by CRLF.

```
var rows = csvRead("data.csv", "name;age;city", "utf8");
print(rows[0].name);    // "Ivan"
print(rows[0].age);     // 30 (int)

// Array of fields and a comma separator
var rows = csvRead("data.csv", #["x","y"], "utf8", ",");

// Write
var data = #[
    #{"name": "Ivan", "age": 30, "city": "Moscow"},
    #{"name": "Anna", "age": 25, "city": "SPb"}
];
csvWrite("data.csv", #["name","age","city"], data, "utf8");
```

### INI

```
iniRead(filename)                       — read a file into a tuple of tuples {section: {key: value}}
iniWrite(filename, data, [encoding])    — write a tuple of sections, returns 1/0
iniReadValue(filename, section, key)    — a single value or null
iniWriteValue(filename, section, key, value, [encoding]) — write/update, returns 1/0
```

- `data` for iniWrite — a tuple `#{"section": #{"key": value, ...}, ...}`;
- values are typed: numbers → `int`/`double`, anything else — a string (an empty value → an empty string);
- comments `;` and `#` are skipped; a section header may end with a comment: `[section] ; note`;
- iniWriteValue updates an existing file in place: replaces a key, appends it to the end of a section, or creates a new section.

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

## max module (MAX Messenger Bot API)

Loading:
```
loadPlugin("plugins/max.dll");
```

### Creation
```
var mx = maxclient();
```

### Connection
```
mx.connect(token)        — validate the token (GET /me) and remember the bot data; 1/0
mx.disconnect()          — disconnect, clear the queue and the marker; 1
```
The bot token is issued at business.max.ru and passed in the `Authorization` header.

### Sending
```
mx.send(recipientId, text)              — message to a user (POST /messages?user_id=)
mx.send(recipientId, text, "chat")      — message to a chat/channel (POST /messages?chat_id=)
mx.send(recipientId, text, "channel")   — same as "chat"
```
The third argument `mode`: if it equals `"chat"` or `"channel"`, `recipientId` is treated as
`chat_id`; with any other value or when the argument is omitted — as `user_id` (direct message).

### Receiving (Long Polling)
```
mx.recv()                — the next message (tuple) or null; when the queue is empty, polls GET /updates
mx.hasMessage()          — 1/0
mx.messageCount()        — number of messages in the queue
mx.setTimeout(sec)       — Long Polling timeout, 1–90 (default 30); with no argument — a getter
```
Fields of the `recv()` tuple: `type`, `timestamp`, `message_id`, `text`, `sender_id`,
`sender_first_name`, `sender_last_name`, `sender_username`, `sender_is_bot`, `chat_id`, `chat_type`.

### SSL and errors
```
mx.setVerify([bool])     — SSL certificate verification (disabled by default)
mx.setCA(file)           — custom CA file for chain verification
mx.lastError()           — last error
```
Properties: `mx.connected`, `mx.pollTimeout`, `mx.botUsername`.

---

## Examples from sample/

### Classes and inheritance
```
class Animal {
    Animal(name, sound) {
        this.name = name;
        this.sound = sound;
    }
    function speak() {
        return "\(this.name) says \(this.sound)!";
    }
}

class Dog : Animal {
    Dog(name) : Animal(name, "Woof") {   // call the base constructor
        this.tricks = 0;
    }
    function fetch() {
        this.tricks = this.tricks + 1;
        return "\(this.name) fetches the stick! (trick #\(this.tricks))";
    }
}

var rex = Dog("Rex");
print(rex.speak());       // Rex says Woof!
print(rex.fetch());       // Rex fetches the stick! (trick #1)
```

### Collections — methods
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
arr.sort(function(a, b) { return a - b; });  // custom sort
arr.reversed();               // new array (does not mutate)
arr.forEach(function(x) { print(x); });
arr.map(function(x) { return x * 2; });
arr.filter(function(x) { return x > 2; });
arr.some(function(x) { return x > 3; });
arr.every(function(x) { return x > 0; });
arr.grouped(function(w) { return w.first(); });
arr.joined(", ");             // "3, 1, 4, 1, 5"
arr.toString();               // "[3, 1, 4, 1, 5]"

// Global functions
var doubled = map(arr, function(x) { return x * 2; });
var evens = filter(arr, function(x) { return x % 2 == 0; });
var total = reduce(arr, function(acc, x) { return acc + x; }, 0);
var r = range(1, 10);          // set {1..9}
var s = sorted(arr);           // set (sorted)
var rev = reversed(arr);       // array (reversed)

// Tuple (associative array)
var t = #{"name": "Ivan", "age": 30};
t.keys(); t.values(); t.get("name"); t.has("age");
t.set("email", "test@mail.ru"); t.remove("email"); t.merge(other);

// Set
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
dic.set("name", "Ivan");  dic.get("name");  dic.has("name");  dic.remove("name");
dic.keys();  dic.values();  dic.size;     // size is a property, no ()
```

### Global functions
```
type(42);           // 1 (int)
type("hello")       // 3 (string)
type(#[1,2])        // 5 (array)
typeName(42)        // "int"
typeName("hello")   // "string"

// Type check:
if (type(val) == 3) print("it is a string");
if (type(val) == 0) print("it is null");

size(#[1,2,3]);     // 3
empty("");          // true
coalesce(null, 42); // 42
min(3, 7);          // 3
max(3, 7);          // 7
clamp(10, 0, 5);    // 5
format("Hello %s!", "World");  // "Hello World!"
eval("print('dynamic')");      // dynamic code
inspect(#[1, 2, 3]);           // detailed output
```
