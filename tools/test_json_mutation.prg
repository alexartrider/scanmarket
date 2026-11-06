var projectDir = file.dirname(file.dirname(file.absolute(system.getcommandline().args[0])));
if (!file.chdir(projectDir))
    throw "Не удалось перейти в каталог проекта: " + projectDir;

var root = json.parse("{\"form\":{\"widgets\":[{\"name\":\"frame\",\"children\":[{\"name\":\"button\",\"geometry\":{\"x\":1}}]}]}}");
var frame = root.form.widgets[0];
var button = frame.children[0];

button.geometry.set("x", 2);
print("local tuple set=" + json.stringify(root));

button.set("geometry", #{"x": 3});
print("replace tuple key=" + json.stringify(root));

frame.children[0] = button;
root.form.widgets[0] = frame;
print("write back indexed=" + json.stringify(root));
return 0;
