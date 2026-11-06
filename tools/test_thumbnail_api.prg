// Read-only smoke test: parser code loads, and a public Ozon CDN image can be fetched/converted.
var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

loadModule("lib/ozon.prg");
var probe = jsCardsProbe(0, 1);
if (str.pos(probe, "querySelectorAll('img')") < 0) throw "Image DOM probe missing";
if (str.pos(probe, "ozone.ru/s3/multimedia-") < 0) throw "Main product CDN is not prioritized";
if (str.pos(probe, "ozonusercontent.com") >= 0) throw "Badge CDN must not be selected";
print("DOM image probe builds: OK");

loadPlugin(file.join(file.programpath(), "plugins", "http.dll"));
var client = HttpClient();
client.setTimeout(12000);
var imageUrl = "https://ir-11.ozone.ru/s3/multimedia-1-6/wc500/20046246702.jpg";
if (!client.get(imageUrl)) throw "GET failed";
if (client.status() != 200) throw "Unexpected HTTP status: " + str.toString(client.status());
var mime = str.lower(str.toString(coalesce(client.getHeader("Content-Type"), "")));
if (str.pos(mime, "image/") != 0) throw "Unexpected MIME type: " + mime;
var bytes = client.getResponseBytes();
if (bytes == null or bytes.size() == 0 or bytes.size() > 8388608) throw "Unexpected image body size";
var png = qt.imageToPng(bytes, 64, 64);
if (png == null or png.size() == 0) throw "qt.imageToPng failed";
print("Public CDN image: HTTP 200, " + mime + ", bytes=" + str.toString(bytes.size()) + ", PNG64=" + str.toString(png.size()));
return 0;
