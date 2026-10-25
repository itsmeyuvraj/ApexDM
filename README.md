# ⚡ ApexDM — Internet Download Manager for Apple Silicon

**ApexDM** is a high-performance, native Internet Download Manager (IDM) clone engineered specifically for **macOS Apple Silicon (M1/M2/M3/M4, ARM64)**.

Built with **Swift, SwiftUI, and POSIX Direct File I/O**, ApexDM delivers maximum throughput with near-zero CPU and memory overhead (~25 MB RAM vs 300+ MB for Electron alternatives).

---

## 🚀 Key Features

- **Dynamic Multi-Segmented Acceleration**:
  - Automatically splits files into 4, 8, 16, or 32 parallel HTTP Range streams.
  - Squeezes maximum bandwidth from high-speed gigabit fiber connections.
- **APFS Zero-Concatenation File I/O (`pwrite`)**:
  - Pre-allocates destination files with zero disk fragmentation on APFS.
  - Streams byte ranges directly to specific offsets concurrently using atomic POSIX `pwrite`.
  - **No post-download merging delay**: As soon as the last chunk completes, the file is already 100% assembled.
- **The Signature IDM Real-Time Segment Visualizer**:
  - Interactive multi-color chunk map displaying live progress across active connections.
  - Per-thread status (Connecting, Transferring, Completed), byte ranges, and connection speeds.
- **Resilient Pause & Resume**:
  - Seamless resumption across network drops, computer sleep, or manual pauses.
- **Clipboard Watcher**:
  - Automatically monitors macOS pasteboard for downloadable file links and prompts an instant download dialog.
- **Smart Category Filtering**:
  - Categorizes downloads into Compressed, Video, Music, Documents, Programs, and Others.
- **Native macOS Design**:
  - Clean SwiftUI interface with SF Symbols, dark/light mode adaptability, menu commands, and keyboard shortcuts.

---

## 🛠 Architecture & Tech Stack

```
ApexDM/
├── Sources/ApexDM/
│   ├── App/
│   │   └── ApexDMApp.swift              # App entry point, menu commands, window lifecycle
│   ├── Core/
│   │   ├── DownloadEngine.swift         # Multi-part concurrent HTTP Range streaming engine
│   │   ├── DownloadManager.swift        # Central queue coordinator, clipboard & state persistence
│   │   ├── DownloadModel.swift          # DownloadItem, SegmentItem, and status models
│   │   ├── NetworkProbe.swift           # Fast HEAD/GET probing for Range support & filenames
│   │   └── ClipboardWatcher.swift       # Background pasteboard monitor
│   ├── Views/
│   │   ├── MainWindowView.swift         # Sidebar categories, toolbar, live speed pill
│   │   ├── DownloadTableView.swift      # Downloads list with context menus & double-click inspection
│   │   ├── SegmentVisualizerView.swift  # Iconic IDM multi-thread visualizer modal
│   │   ├── NewDownloadSheet.swift       # Add URL dialog with live server probe & connection picker
│   │   ├── SettingsView.swift           # Configuration options
│   │   └── Components/
│   │       ├── IDMSegmentBar.swift      # Dynamic colored segment file map
│   │       └── CategoryBadge.swift      # Colored category pills
│   └── Utils/
│       ├── FileUtils.swift              # POSIX pwrite, APFS file allocation, Finder actions
│       └── Formatters.swift             # Human-readable bytes, speed, and ETA formatters
├── Tests/ApexDMTests/                   # Full unit & I/O test suite
└── Scripts/
    └── build_app.sh                     # Compiles release binary & bundles ApexDM.app
```

---

## ⚡ Quick Start

### 1. Launch the App
To run the pre-built, code-signed release `.app`:
```bash
./run.sh
# or
open build/ApexDM.app
```

### 2. Rebuild from Source
To rebuild the native Apple Silicon `.app` bundle:
```bash
./Scripts/build_app.sh
```

### 3. Run Unit Tests
```bash
swift test
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘ + N` | Add new download URL |
| `⌘ + ⇧ + R` | Resume all downloads |
| `⌘ + ⇧ + P` | Pause all downloads |
| `Double Click` | Open Segment Visualizer on selected download |
| `Right Click` | Context menu (Show in Finder, Copy Link, Delete) |
