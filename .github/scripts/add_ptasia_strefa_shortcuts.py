from pathlib import Path
import sys

path = Path(sys.argv[1] if len(sys.argv) > 1 else 'app/lib/main.dart')
s = path.read_text(encoding='utf-8')

marker = "tooltip: 'Ptasia Strefa'"
if marker in s:
    print('Skróty Ptasia Strefa już istnieją w AppBar')
    raise SystemExit(0)

needle = """        actions: [\n          IconButton(\n            onPressed: () => _showInfoDialog(context),\n"""

insert = """        actions: [\n          PopupMenuButton<String>(\n            tooltip: 'Ptasia Strefa',\n            icon: const Icon(Icons.public),\n            onSelected: (value) {\n              if (value == 'www') {\n                _openUrl('https://ptasiastrefa.pl/');\n              } else if (value == 'yt') {\n                _openUrl('https://www.youtube.com/@ptasiastrefa');\n              }\n            },\n            itemBuilder: (context) => const [\n              PopupMenuItem<String>(\n                value: 'www',\n                child: Row(\n                  children: [\n                    Icon(Icons.language),\n                    SizedBox(width: 10),\n                    Text('Ptasia Strefa — strona'),\n                  ],\n                ),\n              ),\n              PopupMenuItem<String>(\n                value: 'yt',\n                child: Row(\n                  children: [\n                    Icon(Icons.play_circle_fill),\n                    SizedBox(width: 10),\n                    Text('Ptasia Strefa — YouTube'),\n                  ],\n                ),\n              ),\n            ],\n          ),\n          IconButton(\n            onPressed: () => _showInfoDialog(context),\n"""

if needle not in s:
    raise SystemExit('Nie znaleziono sekcji AppBar actions — przerwano, żeby nie uszkodzić kodu.')

s = s.replace(needle, insert, 1)
path.write_text(s, encoding='utf-8')
print('Dodano skróty Ptasia Strefa WWW + YouTube do AppBar')
