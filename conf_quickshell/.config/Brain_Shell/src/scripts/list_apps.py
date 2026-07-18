#!/usr/bin/env python3
import os, json, re, configparser

def main():
    # Segue o XDG (XDG_DATA_HOME/XDG_DATA_DIRS) + Flatpak/Snap explícitos.
    # Sem isso, apps de Flatpak (ex. OBS Studio) e Snap não aparecem.
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    bases = [data_home] + [d for d in data_dirs.split(":") if d]
    bases += [
        "/var/lib/flatpak/exports/share",
        os.path.expanduser("~/.local/share/flatpak/exports/share"),
        "/var/lib/snapd/desktop",
    ]
    dirs = []
    for b in bases:
        p = os.path.join(b, "applications")
        if p not in dirs:
            dirs.append(p)
    apps, seen = [], set()

    for d in dirs:
        if not os.path.isdir(d):
            continue
        for fname in sorted(os.listdir(d)):
            if not fname.endswith(".desktop") or fname in seen:
                continue
            seen.add(fname)
            try:
                cp = configparser.ConfigParser(interpolation=None, strict=False)
                cp.read(os.path.join(d, fname), encoding="utf-8")
                if not cp.has_section("Desktop Entry"):
                    continue
                de = cp["Desktop Entry"]
                if de.get("Type", "")              != "Application": continue
                if de.get("NoDisplay", "false").lower() == "true":   continue
                if de.get("Hidden",    "false").lower() == "true":   continue

                name  = de.get("Name", "").strip()
                exec_ = re.sub(r"%[a-zA-Z]", "", de.get("Exec", "")).strip()
                if not name or not exec_:
                    continue

                apps.append({
                    "name":       name,
                    "exec":       exec_,
                    "icon":       de.get("Icon", ""),
                    "categories": de.get("Categories", "")
                })
            except Exception:
                continue

    apps.sort(key=lambda a: a["name"].lower())
    print(json.dumps(apps))

main()
