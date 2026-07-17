#!/usr/bin/env python3
import os
import glob
import json
import sys

def desktop_dirs():
    home = os.path.expanduser('~')

    # XDG_DATA_DIRS already knows where .desktop files live and follows whatever
    # the distro does, so packaging changes don't need a new hardcoded path:
    # Ubuntu ships firefox as a snap, and its entry exists only under
    # /var/lib/snapd/desktop/applications.
    data_home = os.environ.get('XDG_DATA_HOME') or f'{home}/.local/share'
    data_dirs = os.environ.get('XDG_DATA_DIRS') or '/usr/local/share:/usr/share'

    dirs = [os.path.join(data_home, 'applications')]
    dirs += [os.path.join(d, 'applications') for d in data_dirs.split(':') if d]

    # Fallbacks, in case we run without a session environment
    dirs += [
        '/usr/share/applications',
        '/usr/local/share/applications',
        f'{home}/.local/share/applications',
        '/var/lib/flatpak/exports/share/applications',
        f'{home}/.local/share/flatpak/exports/share/applications',
        f'{home}/.nix-profile/share/applications',
        '/var/lib/snapd/desktop/applications',
        '/run/current-system/sw/share/applications',
    ]

    seen = set()
    out = []
    for d in dirs:
        key = os.path.realpath(d)
        if key not in seen:
            seen.add(key)
            out.append(d)
    return out

def fetch_apps():
    apps = {}

    for d in desktop_dirs():
        if not os.path.exists(d):
            continue
            
        for f in glob.glob(os.path.join(d, '**/*.desktop'), recursive=True):
            try:
                with open(f, 'r', encoding='utf-8') as file:
                    app = {'name': '', 'exec': '', 'icon': ''}
                    is_desktop = False
                    no_display = False
                    
                    for line in file:
                        line = line.strip()
                        if line == '[Desktop Entry]':
                            is_desktop = True
                        elif line.startswith('['):
                            is_desktop = False
                            
                        if is_desktop:
                            if line.startswith('Name=') and not app['name']:
                                app['name'] = line[5:]
                            elif line.startswith('Exec=') and not app['exec']:
                                # Strip %u, %f, and @@ placeholders
                                app['exec'] = line[5:].split(' %')[0].split(' @@')[0]
                            elif line.startswith('Icon=') and not app['icon']:
                                app['icon'] = line[5:]
                            elif line.startswith('NoDisplay=true') or line.startswith('NoDisplay=1'):
                                no_display = True
                                
                    if app['name'] and app['exec'] and not no_display:
                        apps[app['name']] = app
            except Exception as e:
                print(f"app_fetcher: skipped {f}: {e}", file=sys.stderr)
                
    # Sort alphabetically and return as JSON
    res = list(apps.values())
    res.sort(key=lambda x: x['name'].lower())
    print(json.dumps(res))

if __name__ == "__main__":
    fetch_apps()


