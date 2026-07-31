#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APP="$DIR/REAPER to Logic Converter.app"

xattr -cr "$APP" 2>/dev/null
chmod +x "$APP/Contents/MacOS/applet" 2>/dev/null
open "$APP"
