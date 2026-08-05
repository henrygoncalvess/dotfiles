#!/usr/bin/env python3
"""Generate src/data/emoji.json from the Unicode emoji-test.txt data file.

The picker reads the generated JSON at startup, so the shell never needs
network access. Re-run this only to bump the Unicode version:

    ./gen_emoji_data.py                      # downloads the latest data
    ./gen_emoji_data.py path/to/emoji-test.txt

Skin-tone variants are dropped: they roughly triple the entry count and the
base emoji is what a picker needs.
"""

import json
import os
import re
import sys
import urllib.request

SOURCE_URL = "https://unicode.org/Public/emoji/latest/emoji-test.txt"
OUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "emoji.json")

# Search aliases for emoji whose CLDR name nobody actually types.
ALIASES = {
    "face with tears of joy": "lol haha funny",
    "rolling on the floor laughing": "lol rofl haha",
    "grinning face": "happy smile",
    "smiling face with smiling eyes": "happy smile blush",
    "loudly crying face": "sob crying sad",
    "red heart": "love",
    "sparkling heart": "love",
    "thumbs up": "ok yes approve +1 like",
    "thumbs down": "no reject -1 dislike",
    "folded hands": "please thanks pray",
    "clapping hands": "applause bravo",
    "fire": "lit hot flame",
    "party popper": "celebrate congrats tada",
    "skull": "dead rip",
    "pile of poo": "poop shit",
    "eyes": "look watching",
    "rocket": "launch ship deploy",
    "check mark button": "done ok yes",
    "cross mark": "no wrong error",
    "warning": "caution alert",
    "light bulb": "idea",
    "hundred points": "100 perfect",
    "winking face": "wink",
    "smiling face with sunglasses": "cool",
    "face with rolling eyes": "annoyed whatever",
    "thinking face": "hmm",
    "money bag": "cash rich",
    "hot beverage": "coffee tea",
    "beer mug": "beer drink",
    "birthday cake": "birthday",
}

GROUP_RE = re.compile(r"^# group: (.+)$")
SUBGROUP_RE = re.compile(r"^# subgroup: (.+)$")
ENTRY_RE = re.compile(r"^([0-9A-F ]+);\s*fully-qualified\s*#\s*(\S+)\s+E[\d.]+\s+(.+)$")


def load_source(argv):
    if len(argv) > 1:
        with open(argv[1], encoding="utf-8") as handle:
            return handle.read()
    print(f"downloading {SOURCE_URL} …", file=sys.stderr)
    with urllib.request.urlopen(SOURCE_URL, timeout=30) as response:
        return response.read().decode("utf-8")


def parse(raw):
    version = ""
    groups = []
    emojis = []
    group = subgroup = ""

    for line in raw.splitlines():
        if line.startswith("# Version:"):
            version = line.split(":", 1)[1].strip()
            continue

        header = GROUP_RE.match(line)
        if header:
            group = header.group(1)
            continue

        header = SUBGROUP_RE.match(line)
        if header:
            subgroup = header.group(1)
            continue

        entry = ENTRY_RE.match(line)
        if not entry or group == "Component":
            continue

        name = entry.group(3)
        if "skin tone" in name:
            continue

        if group not in groups:
            groups.append(group)

        keywords = subgroup.replace("-", " ")
        alias = ALIASES.get(name)
        if alias:
            keywords = f"{keywords} {alias}"

        emojis.append({
            "c": entry.group(2),
            "n": name,
            "g": groups.index(group),
            "k": keywords,
        })

    return {"version": version, "groups": groups, "emojis": emojis}


def main():
    data = parse(load_source(sys.argv))
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")

    print(f"emoji {data['version']}: {len(data['emojis'])} entries, "
          f"{len(data['groups'])} groups -> {os.path.normpath(OUT_PATH)}")


if __name__ == "__main__":
    main()
