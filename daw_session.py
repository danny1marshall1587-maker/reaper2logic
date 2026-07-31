"""
Universal DAW Session Intermediate Model
Normalizes project structure across REAPER (.rpp) and Logic Pro (FCPXML / AAF)
"""

from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any

@dataclass
class DAWItem:
    name: str
    source_file: str
    position: float  # Start time on timeline in seconds
    length: float    # Duration in seconds
    soffs: float = 0.0  # Source audio start offset in seconds
    volume: float = 1.0
    pan: float = 0.0
    mute: bool = False
    fade_in: float = 0.0
    fade_out: float = 0.0
    is_midi: bool = False
    color: Optional[str] = None

@dataclass
class DAWTrack:
    name: str
    id: str = ""
    number: int = 1
    volume: float = 1.0
    pan: float = 0.0
    mute: bool = False
    solo: bool = False
    color: Optional[str] = None
    items: List[DAWItem] = field(default_factory=list)

@dataclass
class DAWMarker:
    name: str
    position: float
    is_region: bool = False
    end_position: float = 0.0
    color: Optional[str] = None

@dataclass
class DAWTempoChange:
    position: float
    bpm: float
    num: int = 4
    denom: int = 4

@dataclass
class DAWSession:
    name: str = "Converted Project"
    sample_rate: int = 44100
    tempo: float = 120.0
    time_sig_num: int = 4
    time_sig_denom: int = 4
    tracks: List[DAWTrack] = field(default_factory=list)
    markers: List[DAWMarker] = field(default_factory=list)
    tempo_map: List[DAWTempoChange] = field(default_factory=list)

    def duration(self) -> float:
        max_t = 0.0
        for track in self.tracks:
            for item in track.items:
                end_t = item.position + item.length
                if end_t > max_t:
                    max_t = end_t
        return max_t or 120.0
