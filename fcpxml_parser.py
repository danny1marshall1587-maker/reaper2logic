"""
Logic Pro FCPXML Parser & Generator
Converts DAWSession to FCPXML (Final Cut Pro XML format used by Logic Pro) and vice versa.
"""

import xml.etree.ElementTree as ET
import os
import re
from typing import List
from daw_session import DAWSession, DAWTrack, DAWItem, DAWMarker, DAWTempoChange

class FCPXMLGenerator:
    @staticmethod
    def generate(session: DAWSession) -> str:
        fcpxml = ET.Element("fcpxml", version="1.9")
        resources = ET.SubElement(fcpxml, "resources")

        # Basic audio format resource
        ET.SubElement(resources, "format", id="r1", name="AudioFormat", frameDuration="100/2400s")

        # Map source files to asset IDs
        asset_map = {}
        asset_counter = 1

        for track in session.tracks:
            for item in track.items:
                filepath = item.source_file or f"{item.name}.wav"
                if filepath not in asset_map:
                    asset_id = f"r{asset_counter + 1}"
                    asset_counter += 1
                    asset_map[filepath] = asset_id

                    # Format file URI
                    if not filepath.startswith("file://"):
                        src_uri = f"file://{os.path.abspath(filepath)}"
                    else:
                        src_uri = filepath

                    dur_str = f"{item.length:.3f}s"
                    ET.SubElement(resources, "asset", {
                        "id": asset_id,
                        "name": item.name,
                        "src": src_uri,
                        "duration": dur_str,
                        "hasAudio": "1",
                        "audioSources": "1",
                        "audioChannels": "2",
                        "format": "r1"
                    })

        library = ET.SubElement(fcpxml, "library")
        event = ET.SubElement(library, "event", name=session.name)
        project = ET.SubElement(event, "project", name=session.name)

        proj_duration = f"{session.duration() + 5.0:.3f}s"
        sequence = ET.SubElement(project, "sequence", {
            "duration": proj_duration,
            "format": "r1",
            "tcStart": "0s",
            "tcFormat": "NDF"
        })

        spine = ET.SubElement(sequence, "spine")

        # Add Markers
        for m in session.markers:
            ET.SubElement(spine, "marker", {
                "start": f"{m.position:.3f}s",
                "duration": "0s",
                "value": m.name
            })

        # Add Tracks as audio role lanes
        for track in session.tracks:
            lane_name = track.name.replace(" ", "_").lower()
            for item in track.items:
                asset_id = asset_map.get(item.source_file or f"{item.name}.wav", "r2")
                clip = ET.SubElement(spine, "asset-clip", {
                    "name": item.name,
                    "ref": asset_id,
                    "offset": f"{item.position:.3f}s",
                    "start": f"{item.soffs:.3f}s",
                    "duration": f"{item.length:.3f}s",
                    "audioRole": lane_name,
                    "lane": str(track.number)
                })

                # Volume envelope if specified
                if item.volume != 1.0:
                    param = ET.SubElement(clip, "adjust-volume", amount=f"{20 * math_log10(max(0.0001, item.volume)):.2f}dB")

        # Pretty XML
        ET.indent(fcpxml, space="  ")
        return '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE fcpxml>\n' + ET.tostring(fcpxml, encoding="utf-8").decode("utf-8")


def math_log10(x: float) -> float:
    import math
    return math.log10(x)

class FCPXMLParser:
    def __init__(self, xml_content: str):
        self.content = xml_content

    def parse(self) -> DAWSession:
        session = DAWSession()
        try:
            root = ET.fromstring(self.content)
        except ET.ParseError:
            return session

        # Map asset id -> filename/src
        assets = {}
        for asset in root.findall(".//asset"):
            aid = asset.get("id")
            src = asset.get("src", "")
            name = asset.get("name", "")
            assets[aid] = (src, name)

        # Parse markers
        for m in root.findall(".//marker"):
            start_str = m.get("start", "0s")
            name = m.get("value", "Marker")
            pos = float(re.sub(r's$', '', start_str))
            session.markers.append(DAWMarker(name=name, position=pos))

        # Parse tracks from asset clips
        tracks_map = {}
        for clip in root.findall(".//asset-clip"):
            name = clip.get("name", "Audio Item")
            ref = clip.get("ref")
            offset_str = clip.get("offset", "0s")
            start_str = clip.get("start", "0s")
            dur_str = clip.get("duration", "0s")
            lane_str = clip.get("lane", "1")
            role_str = clip.get("audioRole", "Track 1")

            pos = float(re.sub(r's$', '', offset_str))
            soffs = float(re.sub(r's$', '', start_str))
            dur = float(re.sub(r's$', '', dur_str))

            src_file = ""
            if ref in assets:
                src_file = assets[ref][0]

            track_name = role_str.replace("_", " ").title()
            if track_name not in tracks_map:
                track_number = len(tracks_map) + 1
                tracks_map[track_name] = DAWTrack(name=track_name, number=track_number)

            track = tracks_map[track_name]
            item = DAWItem(
                name=name,
                source_file=src_file,
                position=pos,
                length=dur,
                soffs=soffs
            )
            track.items.append(item)

        session.tracks = list(tracks_map.values())
        return session
