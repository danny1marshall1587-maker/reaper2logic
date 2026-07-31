"""
REAPER (.rpp) Parser & Generator
Parses REAPER S-expression tags into DAWSession and generates clean .rpp files.
"""

import re
import os
from typing import List, Tuple, Optional
from daw_session import DAWSession, DAWTrack, DAWItem, DAWMarker, DAWTempoChange

class RPPParser:
    def __init__(self, content: str = ""):
        self.content = content

    def parse(self) -> DAWSession:
        session = DAWSession()
        lines = self.content.splitlines()
        
        current_track: Optional[DAWTrack] = None
        current_item: Optional[DAWItem] = None
        in_source = False
        track_counter = 0

        for line in lines:
            stripped = line.strip()
            if not stripped:
                continue

            # Parse Project Tempo: TEMPO 120 4 4
            if stripped.startswith("TEMPO "):
                parts = stripped.split()
                if len(parts) >= 2:
                    try:
                        session.tempo = float(parts[1])
                        if len(parts) >= 4:
                            session.time_sig_num = int(parts[2])
                            session.time_sig_denom = int(parts[3])
                        session.tempo_map.append(DAWTempoChange(0.0, session.tempo, session.time_sig_num, session.time_sig_denom))
                    except ValueError:
                        pass

            # Parse Markers: MARKER 1 12.5 "Verse 1" 0 0 1
            elif stripped.startswith("MARKER "):
                parts = re.findall(r'"[^"]*"|\S+', stripped)
                if len(parts) >= 4:
                    try:
                        pos = float(parts[2])
                        name = parts[3].strip('"')
                        session.markers.append(DAWMarker(name=name, position=pos))
                    except ValueError:
                        pass

            # Track Start: <TRACK
            elif stripped.startswith("<TRACK"):
                track_counter += 1
                current_track = DAWTrack(name=f"Track {track_counter}", number=track_counter)
                session.tracks.append(current_track)

            # Item Start: <ITEM
            elif stripped.startswith("<ITEM") and current_track:
                current_item = DAWItem(name="Item", source_file="", position=0.0, length=0.0)
                current_track.items.append(current_item)
                in_source = False

            # Source Start: <SOURCE WAVE
            elif stripped.startswith("<SOURCE") and current_item:
                in_source = True

            # Track/Item end tag
            elif stripped == ">":
                if in_source:
                    in_source = False
                elif current_item:
                    current_item = None
                elif current_track:
                    current_track = None

            # Inside Track or Item properties
            elif current_item:
                if stripped.startswith("NAME "):
                    name_str = stripped[5:].strip().strip('"')
                    current_item.name = name_str
                elif stripped.startswith("POSITION "):
                    try:
                        current_item.position = float(stripped.split()[1])
                    except ValueError:
                        pass
                elif stripped.startswith("LENGTH "):
                    try:
                        current_item.length = float(stripped.split()[1])
                    except ValueError:
                        pass
                elif stripped.startswith("SOFFS "):
                    try:
                        current_item.soffs = float(stripped.split()[1])
                    except ValueError:
                        pass
                elif stripped.startswith("VOLPAN "):
                    parts = stripped.split()
                    if len(parts) >= 3:
                        try:
                            current_item.volume = float(parts[1])
                            current_item.pan = float(parts[2])
                        except ValueError:
                            pass
                elif stripped.startswith("FADEIN "):
                    parts = stripped.split()
                    if len(parts) >= 3:
                        try:
                            current_item.fade_in = float(parts[2])
                        except ValueError:
                            pass
                elif stripped.startswith("FADEOUT "):
                    parts = stripped.split()
                    if len(parts) >= 3:
                        try:
                            current_item.fade_out = float(parts[2])
                        except ValueError:
                            pass
                elif stripped.startswith("FILE ") or (in_source and stripped.startswith("FILE")):
                    parts = re.findall(r'"[^"]*"|\S+', stripped)
                    if len(parts) >= 2:
                        filepath = parts[1].strip('"')
                        current_item.source_file = filepath
                        if not current_item.name or current_item.name == "Item":
                            current_item.name = os.path.basename(filepath)

            elif current_track:
                if stripped.startswith("NAME "):
                    name_str = stripped[5:].strip().strip('"')
                    current_track.name = name_str
                elif stripped.startswith("VOLPAN "):
                    parts = stripped.split()
                    if len(parts) >= 3:
                        try:
                            current_track.volume = float(parts[1])
                            current_track.pan = float(parts[2])
                        except ValueError:
                            pass
                elif stripped.startswith("MUTE "):
                    parts = stripped.split()
                    if len(parts) >= 2:
                        current_track.mute = parts[1] == "1"
                elif stripped.startswith("SOLO "):
                    parts = stripped.split()
                    if len(parts) >= 2:
                        current_track.solo = parts[1] == "1"
                elif stripped.startswith("PEAKCOL "):
                    parts = stripped.split()
                    if len(parts) >= 2:
                        col_val = int(parts[1])
                        # REAPER color to Hex RGB
                        r = col_val & 0xFF
                        g = (col_val >> 8) & 0xFF
                        b = (col_val >> 16) & 0xFF
                        current_track.color = f"#{r:02x}{g:02x}{b:02x}"

        return session

class RPPGenerator:
    @staticmethod
    def generate(session: DAWSession) -> str:
        lines = [
            '<REAPER_PROJECT 0.1 "7.0/macOS-arm64" 1700000000',
            '  RIPPLE 0',
            '  GROUPS 0',
            '  GROUPOVR 0',
            f'  TEMPO {session.tempo} {session.time_sig_num} {session.time_sig_denom}',
            f'  SAMPLERATE {session.sample_rate} 0 0',
        ]

        # Add Markers
        for idx, m in enumerate(session.markers, 1):
            lines.append(f'  MARKER {idx} {m.position:.6f} "{m.name}" 0 0 1')

        # Add Tracks
        for track in session.tracks:
            lines.append('  <TRACK')
            lines.append(f'    NAME "{track.name}"')
            mute_flag = 1 if track.mute else 0
            solo_flag = 1 if track.solo else 0
            lines.append(f'    VOLPAN {track.volume:.6f} {track.pan:.6f} 1.0 -1.0')
            lines.append(f'    MUTE {mute_flag} 0 0')
            lines.append(f'    SOLO {solo_flag}')

            # Items
            for item in track.items:
                lines.append('    <ITEM')
                lines.append(f'      POSITION {item.position:.6f}')
                lines.append(f'      LENGTH {item.length:.6f}')
                lines.append(f'      SOFFS {item.soffs:.6f}')
                lines.append(f'      NAME "{item.name}"')
                lines.append(f'      VOLPAN {item.volume:.6f} {item.pan:.6f} 1.0 -1.0')
                lines.append(f'      FADEIN 1 {item.fade_in:.6f} 0 1 0 0')
                lines.append(f'      FADEOUT 1 {item.fade_out:.6f} 0 1 0 0')

                src_ext = os.path.splitext(item.source_file)[1].upper().replace('.', '')
                if not src_ext:
                    src_ext = "WAVE"
                if src_ext in ["WAV", "AIFF", "AIF", "MP3", "FLAC"]:
                    src_tag = "WAVE"
                else:
                    src_tag = src_ext

                lines.append(f'      <SOURCE {src_tag}')
                lines.append(f'        FILE "{item.source_file}"')
                lines.append('      >')
                lines.append('    >')
            lines.append('  >')
        lines.append('>')
        return "\n".join(lines)
