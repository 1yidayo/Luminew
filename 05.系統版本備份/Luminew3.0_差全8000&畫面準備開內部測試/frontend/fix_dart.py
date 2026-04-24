import codecs

f = r'c:\xampp\htdocs\Luminew\Luminew\frontend\lib\screens\interview_screens.dart'
with codecs.open(f, 'r', 'utf-8') as f_in:
    lines = f_in.readlines()

for i in range(800, 900):
    if "WebRTC Error:" in lines[i]:
        lines[i] = "        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WebRTC Error: $error')));\n"

with codecs.open(f, 'w', 'utf-8') as f_out:
    f_out.writelines(lines)
