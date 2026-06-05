#!/usr/bin/env python3
import json, os

qs_json = "/tmp/qs_colors.json"
colors_path = os.path.expanduser("~/.config/quickshell/myshell/services/Colors.qml")

if not os.path.exists(qs_json):
    exit(0)

with open(qs_json) as f:
    c = json.load(f)

content = f'''pragma Singleton
import QtQuick
import Quickshell
Singleton {{
    property color primary:          "{c.get('blue', '#ffb1c8')}"
    property color surface:          "{c.get('crust', '#191113')}"
    property color surfaceVariant:   "{c.get('surface1', '#514347')}"
    property color primaryContainer: "{c.get('green', '#703348')}"
    property color foreground:       "{c.get('text', '#efdfe1')}"
    property color tertiary:         "{c.get('peach', '#efbd94')}"
    property color dominant:         "{c.get('base', '#000000')}"
}}
'''

with open(colors_path, "w") as f:
    f.write(content)
