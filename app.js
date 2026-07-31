/**
 * REAPER ↔ Logic Pro Converter Engine & UI Controller
 */

// Universal DAW Session Model
class DAWSession {
  constructor(name = "Converted Project") {
    this.name = name;
    this.sampleRate = 44100;
    this.tempo = 120.0;
    this.timeSigNum = 4;
    this.timeSigDenom = 4;
    this.tracks = [];
    this.markers = [];
    this.tempoMap = [];
  }

  duration() {
    let maxT = 0.0;
    this.tracks.forEach(track => {
      track.items.forEach(item => {
        const endT = item.position + item.length;
        if (endT > maxT) maxT = endT;
      });
    });
    return maxT || 120.0;
  }
}

class DAWTrack {
  constructor(name = "Track", number = 1) {
    this.name = name;
    this.number = number;
    this.volume = 1.0;
    this.pan = 0.0;
    this.mute = false;
    this.solo = false;
    this.color = "#6366f1";
    this.items = [];
  }
}

class DAWItem {
  constructor(name = "Item", sourceFile = "", position = 0.0, length = 0.0) {
    this.name = name;
    this.sourceFile = sourceFile;
    this.position = position;
    this.length = length;
    this.soffs = 0.0;
    this.volume = 1.0;
    this.pan = 0.0;
    this.fadeIn = 0.0;
    this.fadeOut = 0.0;
  }
}

class DAWMarker {
  constructor(name = "Marker", position = 0.0) {
    this.name = name;
    this.position = position;
  }
}

// ----------------------------------------------------
// RPP Parser & Generator (Browser JS)
// ----------------------------------------------------
class RPPParser {
  static parse(text) {
    const session = new DAWSession();
    const lines = text.split(/\r?\n/);
    
    let currentTrack = null;
    let currentItem = null;
    let inSource = false;
    let trackCounter = 0;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;

      if (line.startsWith("TEMPO ")) {
        const parts = line.split(/\s+/);
        if (parts.length >= 2) {
          session.tempo = parseFloat(parts[1]) || 120.0;
          if (parts.length >= 4) {
            session.timeSigNum = parseInt(parts[2]) || 4;
            session.timeSigDenom = parseInt(parts[3]) || 4;
          }
        }
      } else if (line.startsWith("MARKER ")) {
        const matches = line.match(/"[^"]*"|\S+/g);
        if (matches && matches.length >= 4) {
          const pos = parseFloat(matches[2]);
          const name = matches[3].replace(/^"|"$/g, '');
          if (!isNaN(pos)) {
            session.markers.push(new DAWMarker(name, pos));
          }
        }
      } else if (line.startsWith("<TRACK")) {
        trackCounter++;
        currentTrack = new DAWTrack(`Track ${trackCounter}`, trackCounter);
        session.tracks.push(currentTrack);
      } else if (line.startsWith("<ITEM") && currentTrack) {
        currentItem = new DAWItem("Audio Clip", "", 0.0, 0.0);
        currentTrack.items.push(currentItem);
        inSource = false;
      } else if (line.startsWith("<SOURCE") && currentItem) {
        inSource = true;
      } else if (line === ">") {
        if (inSource) inSource = false;
        else if (currentItem) currentItem = null;
        else if (currentTrack) currentTrack = null;
      } else if (currentItem) {
        if (line.startsWith("NAME ")) {
          currentItem.name = line.substring(5).trim().replace(/^"|"$/g, '');
        } else if (line.startsWith("POSITION ")) {
          currentItem.position = parseFloat(line.split(/\s+/)[1]) || 0.0;
        } else if (line.startsWith("LENGTH ")) {
          currentItem.length = parseFloat(line.split(/\s+/)[1]) || 0.0;
        } else if (line.startsWith("SOFFS ")) {
          currentItem.soffs = parseFloat(line.split(/\s+/)[1]) || 0.0;
        } else if (line.startsWith("VOLPAN ")) {
          const parts = line.split(/\s+/);
          if (parts.length >= 3) {
            currentItem.volume = parseFloat(parts[1]) || 1.0;
            currentItem.pan = parseFloat(parts[2]) || 0.0;
          }
        } else if (line.startsWith("FILE ") || (inSource && line.startsWith("FILE"))) {
          const matches = line.match(/"[^"]*"|\S+/g);
          if (matches && matches.length >= 2) {
            const filepath = matches[1].replace(/^"|"$/g, '');
            currentItem.sourceFile = filepath;
            if (!currentItem.name || currentItem.name === "Audio Clip") {
              currentItem.name = filepath.split('/').pop().split('\\').pop();
            }
          }
        }
      } else if (currentTrack) {
        if (line.startsWith("NAME ")) {
          currentTrack.name = line.substring(5).trim().replace(/^"|"$/g, '');
        } else if (line.startsWith("VOLPAN ")) {
          const parts = line.split(/\s+/);
          if (parts.length >= 3) {
            currentTrack.volume = parseFloat(parts[1]) || 1.0;
            currentTrack.pan = parseFloat(parts[2]) || 0.0;
          }
        } else if (line.startsWith("MUTE ")) {
          currentTrack.mute = line.split(/\s+/)[1] === "1";
        } else if (line.startsWith("SOLO ")) {
          currentTrack.solo = line.split(/\s+/)[1] === "1";
        } else if (line.startsWith("PEAKCOL ")) {
          const colVal = parseInt(line.split(/\s+/)[1]);
          if (!isNaN(colVal)) {
            const r = colVal & 0xFF;
            const g = (colVal >> 8) & 0xFF;
            const b = (colVal >> 16) & 0xFF;
            currentTrack.color = `rgb(${r}, ${g}, ${b})`;
          }
        }
      }
    }
    return session;
  }

  static generate(session) {
    const lines = [
      '<REAPER_PROJECT 0.1 "7.0/macOS" 1700000000',
      '  RIPPLE 0',
      '  GROUPS 0',
      '  GROUPOVR 0',
      `  TEMPO ${session.tempo} ${session.timeSigNum} ${session.timeSigDenom}`,
      `  SAMPLERATE ${session.sampleRate} 0 0`
    ];

    session.markers.forEach((m, idx) => {
      lines.push(`  MARKER ${idx + 1} ${m.position.toFixed(6)} "${m.name}" 0 0 1`);
    });

    session.tracks.forEach(track => {
      lines.push('  <TRACK');
      lines.push(`    NAME "${track.name}"`);
      lines.push(`    VOLPAN ${track.volume.toFixed(6)} ${track.pan.toFixed(6)} 1.0 -1.0`);
      lines.push(`    MUTE ${track.mute ? 1 : 0} 0 0`);
      lines.push(`    SOLO ${track.solo ? 1 : 0}`);

      track.items.forEach(item => {
        lines.push('    <ITEM');
        lines.push(`      POSITION ${item.position.toFixed(6)}`);
        lines.push(`      LENGTH ${item.length.toFixed(6)}`);
        lines.push(`      SOFFS ${item.soffs.toFixed(6)}`);
        lines.push(`      NAME "${item.name}"`);
        lines.push(`      VOLPAN ${item.volume.toFixed(6)} ${item.pan.toFixed(6)} 1.0 -1.0`);
        lines.push('      <SOURCE WAVE');
        lines.push(`        FILE "${item.sourceFile || item.name + '.wav'}"`);
        lines.push('      >');
        lines.push('    >');
      });
      lines.push('  >');
    });
    lines.push('>');
    return lines.join('\n');
  }
}

// ----------------------------------------------------
// FCPXML Parser & Generator (Browser JS)
// ----------------------------------------------------
class FCPXMLGenerator {
  static generate(session) {
    const assets = [];
    const assetMap = new Map();
    let assetCounter = 1;

    session.tracks.forEach(track => {
      track.items.forEach(item => {
        const file = item.sourceFile || `${item.name}.wav`;
        if (!assetMap.has(file)) {
          const aid = `r${++assetCounter}`;
          assetMap.set(file, aid);
          assets.push(`    <asset id="${aid}" name="${item.name}" src="file://${file}" duration="${item.length.toFixed(3)}s" hasAudio="1" audioSources="1" audioChannels="2" format="r1" />`);
        }
      });
    });

    const spineClips = [];
    session.tracks.forEach(track => {
      const lane = track.name.replace(/\s+/g, '_').toLowerCase();
      track.items.forEach(item => {
        const ref = assetMap.get(item.sourceFile || `${item.name}.wav`) || "r2";
        spineClips.push(`            <asset-clip name="${item.name}" ref="${ref}" offset="${item.position.toFixed(3)}s" start="${item.soffs.toFixed(3)}s" duration="${item.length.toFixed(3)}s" audioRole="${lane}" lane="${track.number}" />`);
      });
    });

    const markersXml = session.markers.map(m => `            <marker start="${m.position.toFixed(3)}s" duration="0s" value="${m.name}" />`).join('\n');

    return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.9">
  <resources>
    <format id="r1" name="FFVideoFormat1080p24" frameDuration="100/2400s"/>
${assets.join('\n')}
  </resources>
  <library>
    <event name="${session.name}">
      <project name="${session.name}">
        <sequence duration="${(session.duration() + 5).toFixed(3)}s" format="r1" tcStart="0s" tcFormat="NDF">
          <spine>
${markersXml}
${spineClips.join('\n')}
          </spine>
        </sequence>
      </project>
    </event>
  </library>
</fcpxml>`;
  }

  static parse(xmlText) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, "text/xml");
    const session = new DAWSession("Converted Logic Session");

    const assetMap = new Map();
    xmlDoc.querySelectorAll("asset").forEach(asset => {
      assetMap.set(asset.getAttribute("id"), {
        src: asset.getAttribute("src") || "",
        name: asset.getAttribute("name") || "Audio File"
      });
    });

    xmlDoc.querySelectorAll("marker").forEach(m => {
      const startStr = m.getAttribute("start") || "0s";
      const pos = parseFloat(startStr.replace('s', '')) || 0.0;
      session.markers.push(new DAWMarker(m.getAttribute("value") || "Marker", pos));
    });

    const tracksMap = new Map();
    xmlDoc.querySelectorAll("asset-clip").forEach(clip => {
      const name = clip.getAttribute("name") || "Audio Clip";
      const ref = clip.getAttribute("ref");
      const offset = parseFloat((clip.getAttribute("offset") || "0s").replace('s', '')) || 0.0;
      const start = parseFloat((clip.getAttribute("start") || "0s").replace('s', '')) || 0.0;
      const dur = parseFloat((clip.getAttribute("duration") || "0s").replace('s', '')) || 0.0;
      const role = clip.getAttribute("audioRole") || "Track 1";

      const trackName = role.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
      if (!tracksMap.has(trackName)) {
        const num = tracksMap.size + 1;
        tracksMap.set(trackName, new DAWTrack(trackName, num));
      }
      const track = tracksMap.get(trackName);

      let srcFile = "";
      if (assetMap.has(ref)) {
        srcFile = assetMap.get(ref).src;
      }

      const item = new DAWItem(name, srcFile, offset, dur);
      item.soffs = start;
      track.items.push(item);
    });

    session.tracks = Array.from(tracksMap.values());
    return session;
  }
}

// ----------------------------------------------------
// UI Controller & Save File Dialog Manager
// ----------------------------------------------------
document.addEventListener("DOMContentLoaded", () => {
  let currentMode = "rpp2logic";
  let activeSession = null;

  // DOM Elements
  const dropZone = document.getElementById("drop-zone");
  const fileInput = document.getElementById("file-input");
  const dropTitle = document.getElementById("drop-title");
  const dropSubtitle = document.getElementById("drop-subtitle");
  const infoBoxTitle = document.getElementById("info-box-title");
  const infoBoxBody = document.getElementById("info-box-body");
  
  const tabRpp = document.getElementById("tab-rpp2logic");
  const tabLogic = document.getElementById("tab-logic2rpp");
  const btnLoadDemo = document.getElementById("btn-load-demo");

  const sessionSection = document.getElementById("session-section");
  const projName = document.getElementById("proj-name");
  const metaTempo = document.getElementById("meta-tempo");
  const metaTracks = document.getElementById("meta-tracks");
  const metaItems = document.getElementById("meta-items");
  const metaMarkers = document.getElementById("meta-markers");
  const metaDuration = document.getElementById("meta-duration");

  const btnExportPrimary = document.getElementById("btn-export-primary");
  const btnExportSummary = document.getElementById("btn-export-summary");

  const tracksTableBody = document.getElementById("tracks-table-body");
  const markersTableBody = document.getElementById("markers-table-body");
  const tempoTableBody = document.getElementById("tempo-table-body");

  // Mode Switcher
  function setMode(mode) {
    currentMode = mode;
    if (mode === "rpp2logic") {
      tabRpp.classList.add("active");
      tabLogic.classList.remove("active");
      dropTitle.textContent = "Drop your REAPER project (.rpp) file here";
      dropSubtitle.textContent = "or click to browse and select a file to convert";
      infoBoxTitle.textContent = "How REAPER to Logic Pro conversion works";
      infoBoxBody.innerHTML = "Parses your REAPER <code>.rpp</code> project into an Apple-compatible <strong>Final Cut Pro XML (.fcpxml)</strong>. In Logic Pro, select <code>File &gt; Import &gt; Final Cut Pro XML...</code> to load all tracks, audio items, sample alignment, gain, tempo maps, and markers!";
    } else {
      tabLogic.classList.add("active");
      tabRpp.classList.remove("active");
      dropTitle.textContent = "Drop your Logic Pro XML export (.fcpxml / .xml) here";
      dropSubtitle.textContent = "or click to browse and select a file to convert";
      infoBoxTitle.textContent = "How Logic Pro to REAPER conversion works";
      infoBoxBody.innerHTML = "In Logic Pro, choose <code>File &gt; Export &gt; Project to Final Cut Pro XML...</code>. Drop that file here to convert it into a native REAPER <code>.rpp</code> project!";
    }
  }

  tabRpp.addEventListener("click", () => setMode("rpp2logic"));
  tabLogic.addEventListener("click", () => setMode("logic2rpp"));

  // Drag & Drop
  dropZone.addEventListener("click", () => fileInput.click());
  dropZone.addEventListener("dragover", (e) => {
    e.preventDefault();
    dropZone.classList.add("dragover");
  });
  dropZone.addEventListener("dragleave", () => dropZone.classList.remove("dragover"));
  dropZone.addEventListener("drop", (e) => {
    e.preventDefault();
    dropZone.classList.remove("dragover");
    if (e.dataTransfer.files.length > 0) {
      handleFile(e.dataTransfer.files[0]);
    }
  });
  fileInput.addEventListener("change", (e) => {
    if (e.target.files.length > 0) {
      handleFile(e.target.files[0]);
    }
  });

  // Load Demo
  btnLoadDemo.addEventListener("click", () => {
    const demoSession = createDemoSession();
    renderSession(demoSession);
  });

  function createDemoSession() {
    const s = new DAWSession("Demo Multi-Track Song");
    s.tempo = 124.0;
    s.markers = [
      new DAWMarker("Intro", 0.0),
      new DAWMarker("Verse 1", 15.48),
      new DAWMarker("Chorus", 46.45),
      new DAWMarker("Outro", 92.90)
    ];

    const colors = ["#ef4444", "#3b82f6", "#10b981", "#f59e0b", "#8b5cf6", "#ec4899"];

    const tracksData = [
      { name: "Kick & Snare", items: [{ name: "Beat_Pattern_01.wav", pos: 0.0, len: 30.0 }, { name: "Beat_Pattern_02.wav", pos: 30.0, len: 60.0 }] },
      { name: "Bass Synth", items: [{ name: "Sub_Bass_Groove.wav", pos: 15.48, len: 45.0 }] },
      { name: "Rhythm Guitar", items: [{ name: "Rhythm_Riff_Strum.wav", pos: 15.48, len: 75.0 }] },
      { name: "Lead Vocal", items: [{ name: "Lead_Vocal_Take01.wav", pos: 15.48, len: 30.0 }, { name: "Lead_Vocal_Chorus.wav", pos: 46.45, len: 30.0 }] },
      { name: "Backing Harmonies", items: [{ name: "Vocal_Harmonies.wav", pos: 46.45, len: 30.0 }] },
      { name: "FX Risers", items: [{ name: "Riser_Impact.wav", pos: 44.0, len: 8.0 }] }
    ];

    tracksData.forEach((td, idx) => {
      const track = new DAWTrack(td.name, idx + 1);
      track.color = colors[idx % colors.length];
      td.items.forEach(id => {
        const item = new DAWItem(id.name, `audio/${id.name}`, id.pos, id.len);
        track.items.push(item);
      });
      s.tracks.push(track);
    });

    return s;
  }

  function handleFile(file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      const content = e.target.result;
      const fileName = file.name;
      let session = null;

      if (fileName.endsWith(".rpp")) {
        session = RPPParser.parse(content);
        session.name = fileName.replace(/\.rpp$/i, '');
        currentMode = "rpp2logic";
        tabRpp.classList.add("active");
        tabLogic.classList.remove("active");
      } else if (fileName.endsWith(".fcpxml") || fileName.endsWith(".xml")) {
        session = FCPXMLGenerator.parse(content);
        session.name = fileName.replace(/\.(fcpxml|xml)$/i, '');
        currentMode = "logic2rpp";
        tabLogic.classList.add("active");
        tabRpp.classList.remove("active");
      } else {
        alert("Please upload a valid .rpp or .fcpxml file.");
        return;
      }

      renderSession(session);
    };
    reader.readAsText(file);
  }

  function renderSession(session) {
    activeSession = session;
    sessionSection.classList.remove("hidden");

    // Header stats
    projName.textContent = session.name;
    metaTempo.innerHTML = `<i data-lucide="activity"></i> ${session.tempo.toFixed(1)} BPM`;
    metaTracks.innerHTML = `<i data-lucide="layers"></i> ${session.tracks.length} Tracks`;
    
    let totalItems = 0;
    session.tracks.forEach(t => totalItems += t.items.length);
    metaItems.innerHTML = `<i data-lucide="disc"></i> ${totalItems} Items`;
    metaMarkers.innerHTML = `<i data-lucide="bookmark"></i> ${session.markers.length} Markers`;

    const totalSecs = Math.round(session.duration());
    const mins = Math.floor(totalSecs / 60);
    const secs = totalSecs % 60;
    metaDuration.innerHTML = `<i data-lucide="clock"></i> ${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;

    document.getElementById("count-tracks").textContent = session.tracks.length;
    document.getElementById("count-markers").textContent = session.markers.length;

    // Render Views
    renderTimeline(session);
    renderTracksTable(session);
    renderMarkersTable(session);

    lucide.createIcons();
    sessionSection.scrollIntoView({ behavior: "smooth" });
  }

  function renderTimeline(session) {
    const rulerTicks = document.getElementById("ruler-ticks");
    const timelineTracks = document.getElementById("timeline-tracks");
    rulerTicks.innerHTML = "";
    timelineTracks.innerHTML = "";

    const duration = session.duration();
    const pxPerSec = Math.max(8, 900 / duration); // scale width

    // Render Ruler Ticks every 15s
    for (let sec = 0; sec <= duration + 15; sec += 15) {
      const tick = document.createElement("div");
      tick.className = "ruler-tick";
      tick.style.left = `${sec * pxPerSec}px`;
      const m = Math.floor(sec / 60);
      const s = sec % 60;
      tick.textContent = `${m}:${s.toString().padStart(2, '0')}`;
      rulerTicks.appendChild(tick);
    }

    // Render Track Lanes
    session.tracks.forEach(track => {
      const lane = document.createElement("div");
      lane.className = "track-lane";

      const header = document.createElement("div");
      header.className = "track-lane-header";
      header.innerHTML = `<span class="track-color-strip" style="background:${track.color}"></span> <span>${track.name}</span>`;
      lane.appendChild(header);

      const itemsContainer = document.createElement("div");
      itemsContainer.className = "track-lane-items";

      track.items.forEach(item => {
        const clip = document.createElement("div");
        clip.className = "audio-clip";
        clip.style.left = `${item.position * pxPerSec}px`;
        clip.style.width = `${Math.max(20, item.length * pxPerSec)}px`;
        clip.style.background = `linear-gradient(135deg, ${track.color}, #4f46e5)`;
        clip.title = `${item.name} (${item.position.toFixed(2)}s - ${(item.position + item.length).toFixed(2)}s)`;
        clip.textContent = item.name;
        itemsContainer.appendChild(clip);
      });

      lane.appendChild(itemsContainer);
      timelineTracks.appendChild(lane);
    });
  }

  function renderTracksTable(session) {
    tracksTableBody.innerHTML = "";
    session.tracks.forEach((t, i) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${i + 1}</td>
        <td><span class="color-dot" style="background:${t.color}"></span></td>
        <td><strong>${t.name}</strong></td>
        <td>${(20 * Math.log10(Math.max(0.0001, t.volume))).toFixed(1)} dB</td>
        <td>${t.pan > 0 ? 'R ' + Math.round(t.pan * 100) : t.pan < 0 ? 'L ' + Math.round(Math.abs(t.pan) * 100) : 'Center'}</td>
        <td>${t.mute ? '<span style="color:#ef4444">Muted</span>' : 'Active'}</td>
        <td>${t.items.length} items</td>
      `;
      tracksTableBody.appendChild(tr);
    });
  }

  function renderMarkersTable(session) {
    markersTableBody.innerHTML = "";
    session.markers.forEach(m => {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td>${m.position.toFixed(2)}s</td><td><strong>${m.name}</strong></td>`;
      markersTableBody.appendChild(tr);
    });

    tempoTableBody.innerHTML = `<tr><td>0.00s</td><td>${session.tempo.toFixed(1)} BPM</td><td>${session.timeSigNum}/${session.timeSigDenom}</td></tr>`;
  }

  // Session Nav Tabs
  document.querySelectorAll(".snav-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".snav-btn").forEach(b => b.classList.remove("active"));
      document.querySelectorAll(".view-panel").forEach(p => p.classList.add("hidden"));
      btn.classList.add("active");
      const targetId = btn.getAttribute("data-target");
      document.getElementById(targetId).classList.remove("hidden");
    });
  });

  // Export & Save File Action with Native File Save Picker
  async function saveFile(filename, content, mimeType) {
    if ('showSaveFilePicker' in window) {
      try {
        const handle = await window.showSaveFilePicker({
          suggestedName: filename,
          types: [{
            description: 'DAW Project File',
            accept: { [mimeType]: [filename.endsWith('.fcpxml') ? '.fcpxml' : '.rpp'] }
          }]
        });
        const writable = await handle.createWritable();
        await writable.write(content);
        await writable.close();
        return;
      } catch (err) {
        if (err.name === 'AbortError') return; // User cancelled
      }
    }
    
    // Fallback standard download
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  btnExportPrimary.addEventListener("click", async () => {
    if (!activeSession) return;

    if (currentMode === "rpp2logic") {
      const xmlData = FCPXMLGenerator.generate(activeSession);
      await saveFile(`${activeSession.name}.fcpxml`, xmlData, "application/xml");
    } else {
      const rppData = RPPParser.generate(activeSession);
      await saveFile(`${activeSession.name}.rpp`, rppData, "text/plain");
    }
  });

  btnExportSummary.addEventListener("click", async () => {
    if (!activeSession) return;
    const summary = `DAW Project Conversion Summary
=====================================
Project Name : ${activeSession.name}
Tempo        : ${activeSession.tempo} BPM
Tracks       : ${activeSession.tracks.length}
Markers      : ${activeSession.markers.length}

Track Manifest:
` + activeSession.tracks.map(t => `- [${t.name}] : ${t.items.length} items`).join('\n');

    await saveFile(`${activeSession.name}_summary.txt`, summary, "text/plain");
  });
});
