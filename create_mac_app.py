#!/usr/bin/env python3
"""
Generates a native macOS .app bundle ("REAPER to Logic Converter.app")
"""

import os
import sys
import stat

APP_NAME = "REAPER to Logic Converter.app"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(BASE_DIR, APP_NAME)
CONTENTS_DIR = os.path.join(APP_DIR, "Contents")
MACOS_DIR = os.path.join(CONTENTS_DIR, "MacOS")
RESOURCES_DIR = os.path.join(CONTENTS_DIR, "Resources")

def create_mac_app():
    os.makedirs(MACOS_DIR, exist_ok=True)
    os.makedirs(RESOURCES_DIR, exist_ok=True)

    # Info.plist
    info_plist = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.dawconverter.reaper2logic</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>REAPER to Logic Converter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
"""

    with open(os.path.join(CONTENTS_DIR, "Info.plist"), "w", encoding="utf-8") as f:
        f.write(info_plist)

    # Launcher Executable Script
    launcher_script = f"""#!/bin/bash
DIR="$( cd "$( dirname "${{BASH_SOURCE[0]}}" )" >/dev/null 2>&1 && pwd )"
PROJECT_DIR="$( cd "$DIR/../../.." >/dev/null 2>&1 && pwd )"
open "$PROJECT_DIR/index.html"
"""

    launcher_path = os.path.join(MACOS_DIR, "launcher")
    with open(launcher_path, "w", encoding="utf-8") as f:
        f.write(launcher_script)

    # Make launcher executable
    st = os.stat(launcher_path)
    os.chmod(launcher_path, st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    print(f"Successfully created macOS App Bundle: '{APP_NAME}'")
    print(f"You can now double click '{APP_NAME}' or move it to your /Applications folder.")

if __name__ == "__main__":
    create_mac_app()
