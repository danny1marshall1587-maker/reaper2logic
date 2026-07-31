# reaper2logic — REAPER ↔ Logic Pro Project Converter

[![macOS](https://img.shields.io/badge/macOS-Supported-brightgreen.svg)](https://apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Creator: Danny Marshall](https://img.shields.io/badge/Creator-Danny_Marshall-indigo.svg)](#)

A native macOS & Web application tool created by **Danny Marshall** for converting DAW project files bidirectionally between **REAPER (`.rpp`)** and **Logic Pro (`.fcpxml` / AAF)** for easy file travel between DAWs.

---

## 🌟 Key Features

- **Bidirectional Project Conversion**:
  - **REAPER (`.rpp`) ➔ Logic Pro (`.fcpxml`)**: Converts tracks, audio items, timeline placement, source offsets, volume, pan, markers, and tempo maps into Final Cut Pro XML natively importable by Logic Pro.
  - **Logic Pro (`.fcpxml`) ➔ REAPER (`.rpp`)**: Converts Logic Pro exported XML back into REAPER project files (`.rpp`).
- **Interactive Multi-Track Timeline Visualizer**: Inspect your tracks, colored audio clips, item boundaries, and markers directly in the browser before converting.
- **Native macOS App Bundle**: Includes a double-clickable `REAPER to Logic Converter.app` launcher.
- **Python CLI Tool**: Command-line converter for batch processing (`daw_converter.py`).
- **100% Client-Side & Private**: No audio files or project data leave your machine.

---

## 🚀 macOS Quick Start

### Option A: Launch Native macOS App
Double-click **`REAPER to Logic Converter.app`** or move it to your `/Applications` folder.

### Option B: Open Interactive Web Interface
Simply open [`index.html`](index.html) in Safari, Chrome, Edge, or Firefox.

### Option C: Python CLI
Convert a REAPER project to Logic Pro:
```bash
python3 daw_converter.py my_reaper_song.rpp -o my_logic_song.fcpxml
```

Convert a Logic Pro export back to REAPER:
```bash
python3 daw_converter.py my_logic_export.fcpxml -o my_reaper_song.rpp
```

---

## 📥 How to Move Projects Between DAWs

### REAPER ➔ Logic Pro
1. Open the converter app and select **REAPER (.rpp) → Logic Pro (.fcpxml)**.
2. Drag and drop your `.rpp` project file.
3. Click **Download Converted Project** to save your `.fcpxml` file.
4. Launch **Logic Pro**.
5. Select **`File > Import > Final Cut Pro XML...`** and pick the `.fcpxml` file.
6. Logic Pro will automatically populate all tracks, audio regions, sample alignment, and markers into a native Logic Pro session!

### Logic Pro ➔ REAPER
1. In Logic Pro, select **`File > Export > Project to Final Cut Pro XML...`**.
2. Drag the exported `.fcpxml` file into the converter app or run `python3 daw_converter.py`.
3. Download the generated `.rpp` file.
4. Open **REAPER** and select **`File > Open Project...`**.

---

## 👤 Author & Creator

Created by **Danny Marshall**.

## 📄 License
Released under the [MIT License](LICENSE).
