#!/usr/bin/env python3
"""
Builds a native macOS .dmg installer disk image for REAPER to Logic Converter.
"""

import os
import shutil
import subprocess
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
APP_NAME = "REAPER to Logic Converter.app"
APP_PATH = os.path.join(BASE_DIR, APP_NAME)
DMG_STAGE = os.path.join(BASE_DIR, "dmg_stage")
OUTPUT_DMG = os.path.join(BASE_DIR, "reaper2logic.dmg")

def build_dmg():
    print("Building macOS DMG installer...")

    # Ensure app bundle exists
    if not os.path.exists(APP_PATH):
        print(f"Error: App bundle '{APP_NAME}' not found.")
        sys.exit(1)

    # Clean staging directory
    if os.path.exists(DMG_STAGE):
        shutil.rmtree(DMG_STAGE)
    os.makedirs(DMG_STAGE, exist_ok=True)

    # Copy .app to staging
    stage_app_path = os.path.join(DMG_STAGE, APP_NAME)
    shutil.copytree(APP_PATH, stage_app_path)

    # Create /Applications symlink in DMG staging
    app_link = os.path.join(DMG_STAGE, "Applications")
    if not os.path.exists(app_link):
        os.symlink("/Applications", app_link)

    # Remove old DMG if present
    if os.path.exists(OUTPUT_DMG):
        os.remove(OUTPUT_DMG)

    # Create DMG using hdiutil
    cmd = [
        "hdiutil", "create",
        "-volname", "REAPER to Logic Converter",
        "-srcfolder", DMG_STAGE,
        "-ov",
        "-format", "UDZO",
        OUTPUT_DMG
    ]

    print("Running hdiutil...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print(f"🎉 Successfully generated macOS DMG Installer: '{OUTPUT_DMG}'")
    else:
        print(f"Error creating DMG: {res.stderr}")

    # Clean up staging folder
    shutil.rmtree(DMG_STAGE)

if __name__ == "__main__":
    build_dmg()
