#!/usr/bin/env python3
"""
REAPER (.rpp) <-> Logic Pro (.logicx / FCPXML) Project Converter CLI
Packages full REAPER project folders into self-contained Logic Pro (.logicx) bundles.
"""

import sys
import os
import shutil
import stat
import argparse
from rpp_parser import RPPParser, RPPGenerator
from fcpxml_parser import FCPXMLParser, FCPXMLGenerator

def convert_rpp_to_logicx(rpp_path: str, output_path: str = None):
    rpp_path = os.path.abspath(rpp_path)
    rpp_dir = os.path.dirname(rpp_path)
    proj_name = os.path.splitext(os.path.basename(rpp_path))[0]

    if not output_path:
        output_path = os.path.join(rpp_dir, f"{proj_name}.logicx")
    else:
        output_path = os.path.abspath(output_path)
        if not output_path.endswith(".logicx"):
            output_path += ".logicx"

    print(f"Reading REAPER project: {rpp_path}")
    with open(rpp_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    parser = RPPParser(content)
    session = parser.parse()
    session.name = proj_name

    # Create .logicx bundle structure
    media_dir = os.path.join(output_path, "Media", "Audio Files")
    os.makedirs(media_dir, exist_ok=True)

    print(f"Packaging project '{session.name}' into '{os.path.basename(output_path)}'...")
    copied_files = 0

    for track in session.tracks:
        for item in track.items:
            if item.source_file:
                # Find full path of audio file
                candidate_paths = [
                    os.path.join(rpp_dir, item.source_file),
                    os.path.join(rpp_dir, os.path.basename(item.source_file)),
                    os.path.join(rpp_dir, "audio", os.path.basename(item.source_file)),
                    os.path.join(rpp_dir, "media", os.path.basename(item.source_file))
                ]
                
                src_found = None
                for cand in candidate_paths:
                    if os.path.exists(cand) and os.path.isfile(cand):
                        src_found = cand
                        break

                if src_found:
                    filename = os.path.basename(src_found)
                    dest_file = os.path.join(media_dir, filename)
                    if not os.path.exists(dest_file):
                        shutil.copy2(src_found, dest_file)
                        copied_files += 1
                    item.source_file = f"Media/Audio Files/{filename}"
                else:
                    filename = os.path.basename(item.source_file)
                    item.source_file = f"Media/Audio Files/{filename}"

    # Generate FCPXML timeline XML inside bundle
    fcpxml_path = os.path.join(output_path, "Session.fcpxml")
    fcpxml_content = FCPXMLGenerator.generate(session)
    with open(fcpxml_path, "w", encoding="utf-8") as f:
        f.write(fcpxml_content)

    # Create Open in Logic Pro script inside bundle
    launcher_path = os.path.join(output_path, "Open in Logic Pro.command")
    with open(launcher_path, "w", encoding="utf-8") as f:
        f.write('#!/bin/bash\nDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"\nopen -a "Logic Pro" "$DIR/Session.fcpxml"\n')
    
    st = os.stat(launcher_path)
    os.chmod(launcher_path, st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    print(f"\n🎉 Successfully packaged REAPER project folder into Logic Pro bundle:")
    print(f" Location: {output_path}")
    print(f" Audio files bundled: {copied_files}")
    print("\nTo open in Logic Pro:")
    print(f" 1. Double-click '{os.path.join(os.path.basename(output_path), 'Open in Logic Pro.command')}'")
    print(f" 2. Or open Logic Pro and choose File > Import > Final Cut Pro XML... and select '{os.path.basename(output_path)}/Session.fcpxml'")

def main():
    parser = argparse.ArgumentParser(description="Package REAPER project folder into Logic Pro (.logicx) bundle")
    parser.add_argument("input", help="Input REAPER project file (.rpp)")
    parser.add_argument("-o", "--output", help="Output Logic Pro bundle (.logicx)")

    args = parser.parse_args()
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found.")
        sys.exit(1)

    convert_rpp_to_logicx(args.input, args.output)

if __name__ == "__main__":
    main()
