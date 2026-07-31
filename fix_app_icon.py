#!/usr/bin/env python3
"""
Fixes macOS App Icon rendering by:
1. Removing Assets.car (which overrides custom .icns files in macOS 11+)
2. Removing CFBundleIconName from Info.plist so macOS loads applet.icns / app_icon.icns
3. Ensuring applet.icns and app_icon.icns are properly set up
"""

import os
import plistlib
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(BASE_DIR, "REAPER to Logic Converter.app")
RESOURCES_DIR = os.path.join(APP_DIR, "Contents", "Resources")
PLIST_PATH = os.path.join(APP_DIR, "Contents", "Info.plist")
ICNS_SRC = os.path.join(BASE_DIR, "app_icon.icns")

def fix_icon():
    if not os.path.exists(APP_DIR):
        print(f"Error: App bundle {APP_DIR} not found")
        return

    # Remove Assets.car if present
    assets_car = os.path.join(RESOURCES_DIR, "Assets.car")
    if os.path.exists(assets_car):
        os.remove(assets_car)
        print("  ✓ Removed overriding Assets.car")

    # Copy ICNS icon
    if os.path.exists(ICNS_SRC):
        shutil.copy(ICNS_SRC, os.path.join(RESOURCES_DIR, "applet.icns"))
        shutil.copy(ICNS_SRC, os.path.join(RESOURCES_DIR, "app_icon.icns"))
        print("  ✓ Copied applet.icns and app_icon.icns to Resources")

    # Edit Info.plist
    with open(PLIST_PATH, 'rb') as fp:
        plist_data = plistlib.load(fp)

    # Remove CFBundleIconName to prevent macOS asset catalog lookup
    if 'CFBundleIconName' in plist_data:
        del plist_data['CFBundleIconName']

    plist_data['CFBundleIconFile'] = 'applet.icns'

    with open(PLIST_PATH, 'wb') as fp:
        plistlib.dump(plist_data, fp)

    print("  ✓ Updated Info.plist (CFBundleIconFile set to applet.icns, CFBundleIconName removed)")

    # Force LaunchServices to refresh icon cache for the app
    os.system(f'touch "{APP_DIR}"')
    print("🎉 Icon fix complete!")

if __name__ == "__main__":
    fix_icon()
