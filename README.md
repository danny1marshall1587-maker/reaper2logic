# reaper2logic — REAPER ↔ Logic Pro Project Converter

[![macOS](https://img.shields.io/badge/macOS-Supported-brightgreen.svg)](https://apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Creator: Danny Marshall](https://img.shields.io/badge/Creator-Danny_Marshall-indigo.svg)](#)

A native macOS Application & Web tool created by **Danny Marshall** for converting project files bidirectionally between **REAPER (`.rpp`)** and **Logic Pro (`.fcpxml` / AAF)** for easy file travel between DAWs.

---

## 💡 How REAPER ↔ Logic Pro Conversion Works

Because Logic Pro's `.logicx` bundle is an internal proprietary Apple binary package format, Apple designed **Final Cut Pro XML (`.fcpxml`)** as the official native interchange format for Logic Pro.

1. **REAPER (`.rpp`) ➔ Logic Pro**:
   - `reaper2logic` parses your REAPER `.rpp` project file (tracks, audio clips, timeline start positions, clip durations, source offsets, volume gain, pan, markers, and tempo maps).
   - It outputs an Apple-compatible **`Final Cut Pro XML (.fcpxml)`** file.
   - In **Logic Pro**, select **`File > Import > Final Cut Pro XML...`** and pick the `.fcpxml` file.
   - Logic Pro will automatically recreate your entire session as a native `.logicx` project with all tracks, aligned audio regions, and timeline markers!

2. **Logic Pro ➔ REAPER (`.rpp`)**:
   - In Logic Pro, choose **`File > Export > Project to Final Cut Pro XML...`**.
   - Load the exported `.fcpxml` file into `reaper2logic` to generate a native REAPER `.rpp` project file.
   - Open the `.rpp` file directly in REAPER!

---

## 🌟 Features

- **Real Conversion Engine**: Zero dummy/placeholder files. Real S-expression parsing for `.rpp` and DOM/XML parsing for `.fcpxml`.
- **Native macOS Desktop GUI Application**: Open `REAPER to Logic Converter.app` to select files, convert, and pick destination folders using native macOS file dialogs.
- **Interactive Multi-Track Timeline Visualizer**: Inspect your tracks, colored audio clips, item boundaries, and markers in your browser.
- **Zero Dependencies**: Includes a pure Perl engine (`daw_converter.pl`) that runs natively on every macOS system out-of-the-box.

---

## 🚀 Quick Start & Installation

### Option A: Install native macOS App (.dmg)
1. Download **[`reaper2logic.dmg`](https://github.com/danny1marshall1587-maker/reaper2logic/releases/download/v1.0.0/reaper2logic.dmg)**.
2. Double-click `reaper2logic.dmg` in your Downloads folder.
3. Drag **REAPER to Logic Converter.app** into your **Applications** folder!

### Option B: Terminal Command Line
Convert REAPER project to Logic Pro FCPXML:
```bash
perl daw_converter.pl my_song.rpp my_song.fcpxml
```

Convert Logic Pro FCPXML to REAPER project:
```bash
perl daw_converter.pl my_logic_export.fcpxml my_song.rpp
```

---

## 👤 Author & Creator

Created by **Danny Marshall**.

## 📄 License
Released under the [MIT License](LICENSE).
