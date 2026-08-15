#!/usr/bin/env bash

if [ -f /tmp/cliphist-ignore ]; then
    # Simply consume stdin to avoid broken pipe issues and exit cleanly
    cat >/dev/null
    exit 0
fi

exec cliphist store "$@"
