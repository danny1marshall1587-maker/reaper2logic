#!/usr/bin/env python3
"""
REAPER (.rpp) <-> Logic Pro (FCPXML) Project Converter CLI
"""

import sys
import os
import argparse
from rpp_parser import RPPParser, RPPGenerator
from fcpxml_parser import FCPXMLParser, FCPXMLGenerator

def convert_rpp_to_logic(rpp_path: str, output_path: str):
    print(f"Reading REAPER project: {rpp_path}")
    with open(rpp_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    parser = RPPParser(content)
    session = parser.parse()
    session.name = os.path.splitext(os.path.basename(rpp_path))[0]

    print(f"Parsed project '{session.name}': {len(session.tracks)} tracks, {len(session.markers)} markers, tempo {session.tempo} BPM")

    fcpxml_content = FCPXMLGenerator.generate(session)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(fcpxml_content)

    print(f"Successfully generated Logic Pro FCPXML file: {output_path}")
    print("\nTo open in Logic Pro:")
    print(" 1. Launch Logic Pro")
    print(" 2. Select File > Import > Final Cut Pro XML...")
    print(f" 3. Select '{os.path.basename(output_path)}'")


def convert_logic_to_rpp(fcpxml_path: str, output_path: str):
    print(f"Reading Logic Pro FCPXML: {fcpxml_path}")
    with open(fcpxml_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    parser = FCPXMLParser(content)
    session = parser.parse()
    session.name = os.path.splitext(os.path.basename(fcpxml_path))[0]

    print(f"Parsed project '{session.name}': {len(session.tracks)} tracks, {len(session.markers)} markers")

    rpp_content = RPPGenerator.generate(session)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(rpp_content)

    print(f"Successfully generated REAPER project file: {output_path}")
    print("\nTo open in REAPER:")
    print(f" Double-click or open '{os.path.basename(output_path)}' directly in REAPER.")


def main():
    parser = argparse.ArgumentParser(description="Bidirectional REAPER <-> Logic Pro Project Converter")
    parser.add_argument("input", help="Input file path (.rpp or .fcpxml)")
    parser.add_argument("-o", "--output", help="Output file path (.fcpxml or .rpp)")

    args = parser.parse_args()
    input_file = args.input

    if not os.path.exists(input_file):
        print(f"Error: Input file '{input_file}' not found.")
        sys.exit(1)

    ext = os.path.splitext(input_file)[1].lower()

    if ext == ".rpp":
        output_file = args.output or os.path.splitext(input_file)[0] + ".fcpxml"
        convert_rpp_to_logic(input_file, output_file)
    elif ext in [".fcpxml", ".xml"]:
        output_file = args.output or os.path.splitext(input_file)[0] + ".rpp"
        convert_logic_to_rpp(input_file, output_file)
    else:
        print("Error: Input file must be a .rpp (REAPER) or .fcpxml/.xml (Logic Pro export) file.")
        sys.exit(1)

if __name__ == "__main__":
    main()
