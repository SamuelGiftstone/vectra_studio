# VECTRA Studio

**VECTRA Studio** is a native desktop 2D vector graphics editor built with **Flutter** and **Dart**, targeting **Windows Desktop** first (`bitsdojo_window` custom titlebar, `flutter_riverpod` state management, `CustomPainter` vector & typography rendering).

## Core Capabilities

### 1. Editable Vector, Text, Image & Group Document Model
- Shared immutable document hierarchy (`VectorDocument` → `VectorLayer` → `VectorObject` subclasses: `RectangleObject`, `EllipseObject`, `LineObject`, `PolygonObject`, `StarObject`, `PathObject`, `TextObject`, `ImageObject`, and recursive `GroupObject`).
- Zero-padded sequential naming (`Rectangle 01`, `Text 01`, `Group 01`, `Image 01`) managed by `ObjectNamingService` with empty-string sanitization and synchronized renaming across Floating Object Tags, Layers Panel, and Inspector.

### 2. Interactive Editing Tools
- **Selection Tool (`V`)**: Single & `Shift`+multi selection, marquee box selection, drag-to-move (`Shift` axis lock), 8-handle local resizing (`Shift` aspect lock; aspect-locked by default on `ImageObject`), rotation around object center (`Shift` 15° snap), and double-click on any `TextObject` to edit inline on the canvas.
- **Text Tool (`T`)**:
  - **Point Text**: Click anywhere on the canvas to place intrinsic-width multiline text; resizing scales font size proportionally.
  - **Area / Frame Text**: Click-and-drag a rectangular frame to wrap multiline text inside explicit bounds; resizing reflows line wrapping dynamically.
  - **Viewport-Aligned Inline Editing**: Multiline `Enter` newlines, `Ctrl+Enter` or outside-click atomic commit, `Escape` cancel/revert, offline-safe font catalog (`FontCatalog` with `GoogleFonts.config.allowRuntimeFetching = false` and Windows/cross-platform fallbacks), weight (`300–800`), italic, alignment (`Left`, `Center`, `Right`, `Justify`), line height, letter spacing, fill color, stroke outline, and opacity.
- **Pen Tool (`P`)**: Click to place corner anchors, click-drag to pull symmetric cubic Bézier handles, rubber-band live curve preview, click first anchor to close path, `Enter` or double-click to finish open path, `Escape` to cancel.
- **Node Tool (`N`)**: Select and drag path anchors, manipulate incoming/outgoing cubic Bézier handles (`Alt` breaks smooth handles into corner cusps), double-click anchors to toggle Smooth/Corner, and double-click curve segments to split & insert new anchors via De Casteljau subdivision.
- **Shape Tools**: Rectangle (`R`, with corner radius), Ellipse (`E`), Line (`L`, with 45° angle snap), Regular Polygon (`G`, configurable sides), and Star (`S`, configurable points and inner radius ratio).

### 3. Floating Object Tags, Grouping & Artwork Navigation
- **Floating Object Tags**: Viewport-projected tags anchored near object geometry with smart anti-overlap layout, click-to-select, double-click inline rename, and three display modes (`All Tags`, `Selected & Hover`, `Tags Hidden`) never included in exported files.
- **Grouping & Ungrouping**: Group 2+ selected objects into a real `GroupObject` (`Ctrl+G`) and Ungroup (`Ctrl+Shift+G`) while preserving child IDs, styles, z-order, and baked group rotation/opacity; supports nested groups and expandable group trees in the Layers Panel.
- **Artwork Navigation**: Bottom-right floating navigation bar and `View` menu commands for **Find My Artwork** (`Ctrl+Shift+0` — computes exact union bounds across rotated shapes, strokes, text layout, images, and groups, falling back to artboard bounds when empty), **Focus Selection** (`F`), **Fit Artboard** (`Ctrl+0`), and **Reset View 100%** (`Ctrl+1`).

### 4. Asset Import, Portable `.vectra` v2 Storage & Multi-Format Export
- **Local Raster Image Import (`Ctrl+Shift+I`)**: Validates and decodes `.png`, `.jpg`/`.jpeg`, and `.webp` files locally via `package:image`, inserting aspect-locked `ImageObject`s backed by binary `ImageAsset` records.
- **Editable SVG Import**: Secure `package:xml` + custom W3C SVG `<path d="...">` parser (`M/m, L/l, H/h, V/v, C/c, S/s, Q/q, T/t, A/a, Z/z`) converting `<svg>`, `<g>`, `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polygon>`, `<polyline>`, `<path>`, and `<text>` with CSS styles and affine transforms into editable VECTRA objects in one undoable step while rejecting `<script>` and `<!ENTITY` declarations.
- **Portable `.vectra` Project Format (Schema v2)**:
  - Pure-vector projects save as clean UTF-8 JSON `.vectra` files (backward compatible with Schema v1).
  - Projects containing raster images automatically save as portable single-file PKZIP `.vectra` archive bundles (`manifest.json` + binary `assets/<id>.<ext>` via `VectraArchiveCodec`), avoiding JSON base64 bloat while keeping projects 100% self-contained across machines.
- **SVG, PNG & JPEG Artwork Export (`Ctrl+E`)**:
  - **SVG**: Standards-compliant `<rect>`, `<ellipse>`, `<line>`, `<polygon>`, cubic Bézier `<path>`, `<text>`/`<tspan>`, recursive `<g>` groups, and data-URI `<image>` elements.
  - **PNG**: Lossless RGBA rasterization via `ArtworkRenderer` + `PictureRecorder` at `1x–4x` scale with optional transparent alpha background.
  - **JPEG**: Opaque rasterization at `1x–4x` scale with configurable background color and quality (`10%–100%`).

## Keyboard Shortcuts

| Action | Shortcut |
| --- | --- |
| Selection / Pen / Text / Node / Hand | `V` / `P` / `T` / `N` / `H` |
| Rectangle / Ellipse / Line / Polygon / Star | `R` / `E` / `L` / `G` / `S` |
| New / Open / Save / Save As | `Ctrl+N` / `Ctrl+O` / `Ctrl+S` / `Ctrl+Shift+S` |
| Import Raster Image | `Ctrl+Shift+I` |
| Export Artwork (SVG, PNG, JPEG) | `Ctrl+E` |
| Undo / Redo | `Ctrl+Z` / `Ctrl+Shift+Z` (`Ctrl+Y`) |
| Group / Ungroup Selection | `Ctrl+G` / `Ctrl+Shift+G` |
| Duplicate / Delete / Select All | `Ctrl+D` / `Del` / `Ctrl+A` |
| Find My Artwork / Focus Selection | `Ctrl+Shift+0` / `F` |
| Fit Artboard / Reset View (100%) / Toggle Grid | `Ctrl+0` / `Ctrl+1` / `Ctrl+'` |

## Windows Desktop Setup & Running Locally

1. Ensure Flutter Desktop for Windows (Visual Studio C++ desktop workload + Flutter SDK `>=3.16.0` / Dart `>=3.2.0`) is installed.
2. If platform runner files beyond `windows/runner/main.cpp` have not yet been generated on your machine, generate missing Windows scaffolding without overwriting existing files:
   ```bash
   flutter create --platforms=windows .
   ```
   *(Verify `windows/runner/main.cpp` retains `#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>` and `auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);`.)*
3. Fetch dependencies, analyze, run all unit tests, and launch on Windows:
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter run -d windows
   ```
