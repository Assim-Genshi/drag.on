# Drag.on - macOS Productivity Drop Shelf & Image Converter

**Drag.on** (pronounced "Dragon") is a highly polished, non-sandboxed macOS Accessory utility designed to supercharge drag-and-drop workflows. It provides a temporary floating "shelf" (or "Lair") for files. Users can summon the Lair on demand by simply dragging any file and shaking it, or via a menu bar status item.

In addition to serving as a file shelf, Drag.on includes a native **Image Converter** that converts dropped images to **WebP**, **ICNS**, **PNG**, **JPEG**, **ICO**, and **PDF** formats in-place, instantly feeding converted files back onto the shelf for immediate drag-out.

---

## 🛠 Technology Stack

- **OS Platform**: macOS 14.6+ (Runs as an Accessory/Agent App, hidden from the Dock by default via `activationPolicy = .accessory`).
- **UI Frameworks**:
  - **SwiftUI**: Drives the main user interface overlay (`LairView`), management grid (`FileGridCell`), empty states, close buttons, file counts, the convert panel (`ConvertView`), settings (`SettingsView`), and all reusable UI components.
  - **AppKit (Cocoa)**: Manages window characteristics (`LairWindow`, `ConvertPanel`, and Settings window as borderless `NSPanel` subclasses), global dragging/mouse tracking, system status items, context menus, and native multi-file dragging.
- **Image Conversion**: Uses native macOS command-line utilities `/usr/bin/sips` and `/usr/bin/iconutil` executed asynchronously via Foundation's `Process` class, alongside `libwebp` wrapper for direct encoding and `CGImageDestination` for bitmap structures.
- **Persistence**: `UserDefaults` with JSON encoding and security-scoped bookmark data for persistent file resolution across system restarts and path movements.
- **Third-Party Packages**:
  - **KeyboardShortcuts**: Manages system-wide global hotkey registration, key recording UI, and key presses for toggling the Lair, opening from clipboard, and restoring previous shelf contents.
  - **LaunchAtLogin**: Simple helper package to easily schedule the app to start automatically upon user login.
- **Concurrency & Concurrency Safety**: Developed under Swift 6 strict concurrency checks. Implements thread-safe cache transitions (`OSAllocatedUnfairLock`), actors for service pipelines, and asynchronous off-main-thread task groups.

---

## 📂 Codebase & Component Structure

### Core Application
- **[DragOnApp.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/App/DragOnApp.swift)**:
  - Main entry point of the app.
  - Registers the `AppDelegate` class via `@NSApplicationDelegateAdaptor`.
  - Sets the application's activation policy to `.accessory` upon launch, removing the app icon from the macOS Dock.
- **[AppDelegate.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/App/AppDelegate.swift)**:
  - Manages the application lifecycle.
  - Instantiates `LairStore`, `ImageConverter`, and `DragMonitor`.
  - Registers global `KeyboardShortcuts` key-up listeners for toggling the Lair, importing from clipboard, and restoring the previous Lair state.
  - Configures the system menu bar status item (status icon, custom drop target, click interactions, and a contextual dropdown menu matching current global hotkeys).
  - Starts the `DragMonitor` global mouse polling.
  - Observes the `ShakeDetector` callback to show the floating `LairWindow` under the cursor.

### Window Management & AppKit Bridge
- **[LairWindow.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/LairWindow.swift)**:
  - Subclasses `NSPanel` with a borderless, non-activating, and floating configuration to stay on top of all windows.
  - Uses `NSVisualEffectView` with `.hudWindow` materials for a modern glassmorphism aesthetic.
  - Tracks whether the window was summoned by a shake action to trigger auto-hiding when a drag session ends (`wasShownByShake` state).
  - Stores `lastDropLocation` relative to the screen to help sub-views perform targeted drop animations.
  - Adjusts its geometry dynamically based on active modes:
    - **Standard mode**: `260 × 280` (with 34pt corner radius)
    - **Compact mode**: `200 × 260`
    - **Management view**: `360 × 440`
  - Leverages Swift `withObservationTracking` to adapt its interface size, bounds, and layout dynamically.
- **[ConvertPanel.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/ConvertPanel.swift)**:
  - Subclasses `NSPanel` with borderless, non-activating, and full-size-content-view configuration.
  - Dimensions: **320 × 380** pixels with a corner radius of `20pt`.
  - Positions itself in the center of the active screen containing the Lair window.
  - Forces application activation and makes itself the key window on appear to receive immediate focus.
- **[DropOverlayView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/DropOverlayView.swift)**:
  - AppKit overlay view that catches incoming file/text pasteboard dragging payloads.
  - Records the screen coordinates of drops into the window's `lastDropLocation` before forwarding local file additions to `LairStore`.
- **[DropTargetView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/DropTargetView.swift)**:
  - AppKit view capturing incoming dragging sessions (`.fileURL`, `.URL`, `.string`).
  - Triggers haptic feedback (`.alignment`) via `LairWindow` when an external drag enters the view boundary.
  - Forwards drops to `LairStore.addFilesAsync(urls:)` and browser drops/strings to `LairStore.addWebDrop(url:)`.
- **[FirstMouseHostingView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/FirstMouseHostingView.swift)**:
  - A subclass of `NSHostingView` that allows SwiftUI buttons to respond to a single click even when the panel window is not currently active/key.
  - Handles drop target registration and forwards drag session inputs to the `LairStore`.
- **[FilePileView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/FilePileView.swift)**:
  - AppKit view (`FilePileNSView`) placed under the SwiftUI hosting view.
  - Renders up to 5 visual file cards styled as a stacked pile with shadow overlays and organic rotations (configured as a fixed offset array `[0, -5, 4, -3, 6]`).
  - Converts `lastDropLocation` screen coordinates into a local coordinate system and triggers targeted direction-aware bounce animations on newly dropped cards.
  - Manages card recycling, animations, and coordinates layouts based on whether standard, compact, or convert modes are active.
- **[FileCardView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/FileCardView.swift)**:
  - AppKit view (`FileCardNSView`) representing a single card on the pile.
  - Implements `NSDraggingSource` to facilitate dragging a file *out* of the Lair.
  - Sets cards to be transparent hit-test targets during active external drags, delegating drop resolution to the underlying `FilePileNSView`.
  - Implements `performBounceAnimation(offsetX:offsetY:delay:)` using keyframed translation and rotation wiggles for interactive feedback on drops.
  - Controls card fade-outs when active drags begin, handles the custom contextual right-click menu, and runs clear/cloud-puff animations respecting user settings.
- **[DragSourceHelper.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Windows/DragSourceHelper.swift)**:
  - `NSViewRepresentable` bridging AppKit mouse tracking to SwiftUI grid cells inside the Lair Manager grid.
  - Intercepts clicks, toggle highlights, hover events, and triggers a multi-file drag-out session (`beginDraggingSession(with:event:source:)`) if the user drags a selection.
  - Builds a comprehensive contextual right-click menu tailored to files or folders, offering actions like Open, Open with Application, Open in Terminal (supporting Terminal, iTerm2, and Warp), Reveal in Finder, Copy Path, Rename, Duplicate, Compress (ZIP creation via `/usr/bin/ditto`), and Convert.

### Services & Interaction Logic
- **[DragMonitor.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/DragMonitor.swift)**:
  - Polls the system mouse state at **60Hz** (every 16ms) during active drags.
  - Offloaded to a dedicated high-priority serial queue (`com.yokai.drag-on.drag-monitor` with `.userInteractive` QoS) to prevent disk I/O and synchronous IPC pasteboard checks from hitching the main thread.
- **[ShakeDetector.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/ShakeDetector.swift)**:
  - Aggregates high-frequency coordinate samples (up to 40 samples in a 0.5s window).
  - Processes horizontal velocity (requires `minVelocity = 300.0` px/s) and tracks direction changes (reversals) to detect shakes.
  - Implements a horizontal boundary amplitude limit (`maxAmplitude = 150.0` px) to ignore standard horizontal drags, and integrates a cooldown period (`1.5s`).
- **[LairStore.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/LairStore.swift)**:
  - Central manager of `FileItem` objects, conforming to `FileStoring`.
  - Serializes items to/from `UserDefaults` via JSON.
  - Resolves security-scoped bookmark data on launch and automatically prunes stale files.
  - Performs non-blocking asynchronous bookmark creation via a Swift `TaskGroup` inside `addFilesAsync(urls:)`.
  - Supports restoring the previous non-empty shelf contents (`restorePreviousLair()`).
- **[WebDropService.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/WebDropService.swift)**:
  - Actor-isolated utility that handles downloading images dropped from web browsers.
  - Performs downloads via `URLSession.shared.download`.
  - Resolves filenames from headers/URLs, maps MIME types to extensions, and guarantees file name uniqueness at the destination folder.
- **[ImageConverter.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/ImageConverter.swift)**:
  - Main-actor-isolated coordinator bridging the conversion pipeline to the SwiftUI UI state.
  - Parses file items into `ConversionJob` parameters, generates `ResolvedOutputInfo`, and instantiates `ConversionQueue` to process files asynchronously.
- **[ConversionQueue.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/ConversionQueue.swift)**:
  - Actor-isolated queue processing conversion tasks sequentially.
  - Sequentially validates source folders and files, handles SVG pre-rasterization pipelines, executes overwrite policies (Auto-rename, Overwrite, Skip), verifies the output integrity, and reports updates to the UI.
- **[ConversionValidator.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/ConversionValidator.swift)**:
  - Validates `ConversionJob` entries. Checks path access, write permissions on output directories, file size limits (generates a warning above 50MB), and format compatibility.
- **[SVGRasterizer.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/SVGRasterizer.swift)**:
  - Handles vector format pre-processing. Loads vector assets natively using AppKit's `NSImage`.
  - Computes scale-preserving resolutions (maximum 2048px) and draws the vectors into a `CGBitmapContext` to write temporary PNG inputs for down-stream converters.
- **[ThumbnailCache.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Services/ThumbnailCache.swift)**:
  - Main-actor-isolated cache wrapping an `NSCache<NSString, CachedThumbnail>`.
  - Wraps non-`Sendable` `NSImage` items inside a thread-safe `SendableImage` structure to cross concurrency boundaries safely.
  - Leverages `QLThumbnailGenerator` inside background threads, falling back to downscaled `CGImageSource` objects for raw images or file system icons.

### SwiftUI Views & Design Components
- **[LairView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Lair/LairView.swift)**:
  - Primary shelf content view. Manages top navigation, empty states, dashed borders (with 22pt corner radius), file counters, and summon transitions.
  - Handles the Lair Manager grid overlay displaying item selections and batch operational buttons (Deselect, Open, Reveal, Convert, Delete).
- **[LairCircleButton.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Lair/LairCircleButton.swift)**:
  - A highly polished circular icon button (30x30) with adaptive background styles for light and dark backgrounds.
  - Scales up by 15% on hover with custom spring animations.
- **[ConvertView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Convert/ConvertView.swift)**:
  - Dialog showing selected image card stacks, format selection menu popovers, quality configuration slider, and the reflective "Convert Now" button.
  - Reads output settings from `UserDefaults` on startup. Supports "Same Folder", "Downloads", and "Custom Folder" routing.
  - Adopts `SelectorInputLabel` and `FolderIconPreviewView` for polished dropdown controls.
- **[ConvertProgressView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Convert/ConvertProgressView.swift)**:
  - Shows conversion progress with a detailed circular progress ring, phase descriptions, and file status metrics.
- **[ConvertSuccessView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Convert/ConvertSuccessView.swift)**:
  - Complete confirmation panel.
  - Displays draggable preview cells ("ghost cards") of the outputs, a "Reveal in Finder" action, and destination configuration buttons ("Clear & Add" or "Add to Lair").
- **[ConvertFailureView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Convert/ConvertFailureView.swift)**:
  - Displays error logs, failed item details, warning symbols, and a dismiss link.
- **[GhostCardView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Components/GhostCardView.swift)**:
  - Draggable preview thumbnail displayed inside the success state scroll area.
- **[AsyncThumbnailView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Components/AsyncThumbnailView.swift)**:
  - Helper view that asynchronously triggers, loads, and draws cached thumbnails.
- **[SelectorInputLabel.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Components/SelectorInputLabel.swift)**:
  - A premium, reusable dropdown input label component styled with frosted glass material, top highlight borders, and centered text layouts.
  - Incorporates `SelectorIcon` (custom SF symbols) and `FolderIconPreviewView` (renders native macOS system icons for selected directories).
- **[WandIcon.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Components/WandIcon.swift)**:
  - Availability-gated vector component mapping `wand.and.sparkles` on macOS 15+ and falling back to `wand.and.rays` on older operating systems.
- **[CapsuleSlider.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Components/CapsuleSlider.swift)**:
  - Custom horizontal slider for adjusting output compression quality with precise hover tracks and progress indicators. Decorated with `topHighlightBorder()`.
- **[SettingsView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Views/Settings/SettingsView.swift)**:
  - Arc browser-style visual preference view with customized window configuration (`SettingsWindowConfigurator`) to enforce chromeless borders and slide-shifted AppKit traffic lights.
  - Organizes preferences into clear grids:
    - **General**: Launch At Login, Preferred Terminal (Terminal, iTerm2, Warp), Web Drops Location path picker, Shake Sensitivity, Summon Position (Above/Below/Left/Right), and Summon Distance (Small/Medium/Large).
    - **Conversion**: Default format and Default output location (Same Folder, Downloads, or Custom).
    - **Appearance**: Compact Mode toggle, Cloud Animation toggle, and visual App Theme picker cards (System, Light, Dark).
    - **Shortcuts**: Custom hotkey recorders (`CustomShortcutRecorder` using standard `NSEvent` key-press monitors) to binds actions for toggling the Lair, opening clipboard content, and recalling previous shelf items.

### Utility Structures
- **[LairConstants.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Utilities/LairConstants.swift)**:
  - Absolute dimensions, corner radii, material states, margins, menu constants, and icons utilized by windows and dialog structures.
  - Declares the `topHighlightBorder()` view modifier and modifier extensions.
- **[ImageExtensions.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Utilities/ImageExtensions.swift)**:
  - Declares the `SupportedImageExtensions` lookup set to determine format validation.
- **[Color+Hex.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Utilities/Color+Hex.swift)**:
  - Extension for initializing SwiftUI `Color` views from hex strings.
- **[View+Cursor.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Utilities/View+Cursor.swift)**:
  - Introduces `pointerCursor()` modifiers to display AppKit hand pointers on hover.
- **[SettingsOpener.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Utilities/SettingsOpener.swift)**:
  - A thread-safe bridge to open the SwiftUI settings panel from the AppKit `AppDelegate` environment.
- **[Logger+App.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/Utilities/Logger+App.swift)**:
  - Subsystem-based logger category declarations.

---

## 🎨 Visual Design & Layout Architecture

### Lair Shelf Overlay
- **Layout Profiles**:
  - **Standard**: `260 × 280` frame, `34pt` corner radius, centered stacked previews, full-width actions at the bottom.
  - **Compact**: `200 × 260` frame, `26pt` corner radius, smaller previews, file counts inside a simplified header bar.
  - **Management**: `360 × 440` frame, `26pt` corner radius, multi-column adaptive layout grids.
- **Background Vibrant Layer**: Uses `.hudWindow` vibrancy. Inactive windows are styled with custom border colors (`Color("border-color")`), which adapt to glowing blue highlights (`Color.skyblue`) during active drag operations.
- **Empty Dashed State**: Outer outline bordered with a dotted border (`StrokeStyle(lineWidth: 1.5, dash: [9, 4])` with 22pt corner radius) padded from margins, which automatically fades out when files are present.
- **Bottom Stack**: Combines frosted action pills (32pt heights) that adaptively show image conversion buttons when images are on the shelf.

### Image Converter Panel
- **Frame Spec**: `320 × 380` boundary with a solid white background and a gradient-masked top clouds banner (`sky_clouds_bg`) on light mode.
- **Header**: Absolute-positioned close button (`LairCircleButton` with `isLightBackground: true`) on the left, with title strings centered.
- **Input Fields**: Input badges styled with thin border indicators, including chevron dropdowns, folder selection popovers, and `topHighlightBorder()` modifications.
- **Convert Now Button**: Designed with a high-contrast sky-blue gradient (`#4EA3FF → #95D7FD`), diagonal semi-translucent glass sheen overlays, and large glowing shadows.

---

## 🔄 Interaction Flow & Conversion Engine Pipeline

### 1. Step-by-Step User Interaction Flow

1. **Summoning the Lair**:
   - **Trigger Options**:
     - *Shake Summons*: The user drags a file from Finder or any other application and shakes the mouse cursor horizontally. The `DragMonitor` detects drag states at 60Hz and feeds coordinate pairs to `ShakeDetector`, which measures speed thresholds (>300 px/s) and reversals to verify a shake.
     - *Keyboard Hotkey*: The user presses the global keyboard shortcut (`Option + Command + L` by default, recorded via `CustomShortcutRecorder`).
     - *Status Menu*: The user clicks "Show Lair" inside the macOS Status Menu Bar.
   - **Window Placement**: The float-HUD `LairWindow` is instantly displayed offset from the cursor according to user preferences (`summonPosition`: Above/Below/Left/Right, and `summonDistance`: Small/Medium/Large gaps).
2. **Dropping & Staged Transitions**:
   - The user drops files over the Lair window.
   - `DropOverlayView` intercepts the drop payload, stores the exact drop coordinates into `LairWindow.lastDropLocation`, and cancels any pending auto-hide timers.
   - The file URLs are sent to `LairStore` to resolve security-scoped bookmark data and create local `FileItem` representations.
   - Newly added cards in `FilePileNSView` are positioned. The window translates `lastDropLocation` into the local view coordinate system.
   - Each new card is animated using a staggered delay sequence (`currentIndex * 0.035s` offset) with three simultaneous animations:
     1. *Fade-in*: Opacity scale from `0.0` to `1.0`.
     2. *Scale*: Dynamic transform scale from `1.15` to `1.0` (identity).
     3. *Bounce & Settling*: A high-performance direction-aware keyframe slide animation (`transform.translation.x` and `transform.translation.y`) originating from the exact drop coordinate, capped at a maximum slide offset of `300.0` px, and ending with a soft rotational wiggle (`transform.rotation.z` between `-0.016` and `0.016` radians) to simulate organic stacking.
   - A background thread schedules high-resolution thumbnail rendering via `QLThumbnailGenerator` (falling back to custom downscaled `CGImageSource` allocations or file system icon bindings), which cross-fades into the image card in `0.15s` to `0.25s`.
3. **Initiating Image Conversion**:
   - If the shelf contains only supported image types, a frosted bottom action pill ("Convert…" with a wand icon) fades into view.
   - Clicking the button summons the centered `ConvertPanel` holding the `ConvertView` interface. The panel forces focus to handle immediate keyboard operations.
4. **Configuring Format & Destination**:
   - The user selects the target format (**WebP**, **PNG**, **JPEG**, **ICNS**, **ICO**, or **PDF**) via a `SelectorInputLabel` dropdown.
   - If WebP or JPEG is selected, a custom `CapsuleSlider` with interactive hover tracks lets the user configure compression quality (0.01 to 1.0).
   - The user selects the destination folder using a dropdown:
     - *Same Folder*: Saves outputs next to the original files.
     - *Downloads*: Resolves path directly to `~/Downloads`.
     - *Custom Folder...*: Launches a native `NSOpenPanel` directory selector. The selected folder name and its native OS icon preview are displayed in the dropdown button label.
     - *Web Drop Routing*: Dropped images sourced from web browser caches (which map to temporary system paths like `/var/folders/` or `/Caches/`) are automatically redirected to `~/Downloads` (or the customized Web Drops folder) to prevent saving files in hidden system directories.
5. **Sequential Conversion Execution**:
   - Clicking "Convert Now" instantiates an actor-isolated `ConversionQueue` and starts processing.
   - The user interface enters a progress state displaying a spinning circular ring, item counters, and active phases (`validating`, `rasterizing`, `converting`, `verifying`).
6. **Confirming Success**:
   - Upon successful completion of all jobs, the success screen displays draggable preview cells ("ghost cards") of the outputs.
   - The user can click "Reveal in Finder" or select a shelf storage action:
     - *Add to Lair*: Appends the newly converted file paths to the existing shelf stack.
     - *Clear & Add*: Wipes the original files from the shelf and populates it only with the new outputs.
7. **Drag-Out & Clean Up**:
   - The user drags the stacked cards or selected grid items out of the shelf and drops them into another application (Finder, Photoshop, email client, Slack, etc.).
   - If the shelf is emptied, or if the user clicks "Clear", a 5-frame cloud animation (`cloud animation frame 1` through `5`) plays as an overlay on each card as it scales down to `0.6` and fades out (can be disabled in Settings via the `enableCloudAnimation` preference).

---

### 2. Advanced Conversion Engine Mechanics

All low-level image processing is isolated off the main thread inside the thread-safe `ConversionEngine` structure.

#### WebP Encoding (`libwebp` / `WebPEncoder`)
- Loads the source image via `CGImageSource` and draws it into a raw RGBA memory-mapped pixel buffer (`CGImageAlphaInfo.premultipliedLast`).
- Translates the quality parameter to a standard float configuration (e.g., `quality * 100.0`).
- Executes the `libwebp` encoder wrapper (`WebPEncoder.encode`) directly against the buffer base address using stride dimensions, then writes the returned WebP binary payload to disk.

#### PNG & JPEG Rendering (`CGImageDestination`)
- Loads source image bitmaps.
- Wraps the output destination path inside a `CGImageDestination` referencing `UTType.png` or `UTType.jpeg`.
- Passes the lossy compression quality dictionary (`kCGImageDestinationLossyCompressionQuality: quality`) if JPEG is selected, then finalizes the writing destination.

#### ICNS Icon Construction (`sips` + `iconutil`)
- Since macOS icon files require multi-resolution sets, ICNS compilation leverages subprocess wrappers:
  1. *Square Crop*: Spawns `/usr/bin/sips` with `--cropToHeightWidth` arguments to make the input perfectly square.
  2. *Upscale*: Runs `sips` with `--resampleHeightWidth 1024 1024` to ensure a consistent high-resolution base.
  3. *Folder Generation*: Creates a temporary folder ending in `.iconset`.
  4. *Scale Resampling*: Asynchronously triggers 10 sequential `sips` processes to export all standard Apple icon assets into the directory:
     - `icon_16x16.png` (16px) & `icon_16x16@2x.png` (32px)
     - `icon_32x32.png` (32px) & `icon_32x32@2x.png` (64px)
     - `icon_128x128.png` (128px) & `icon_128x128@2x.png` (256px)
     - `icon_256x256.png` (256px) & `icon_256x256@2x.png` (512px)
     - `icon_512x512.png` (512px) & `icon_512x512@2x.png` (1024px)
  5. *Compilation*: Invokes `/usr/bin/iconutil -c icns <path>.iconset -o <destination>.icns` to assemble the folder assets into the final ICNS binary.
  6. *Clean Up*: Automatically deletes the temporary folder and its contents.

#### ICO Multi-Frame Packing (`CGImageDestination`)
- Crops the source image to a square.
- Resizes the square image using high-quality interpolation into all Microsoft ICO standard sizes: `[16, 24, 32, 48, 64, 128, 256]`.
- Instantiates a multi-frame `CGImageDestination` specifying the Microsoft ICO UTI (`com.microsoft.ico` or `"com.microsoft.ico" as CFString`).
- Sequentially appends each of the 7 resized bitmaps to the destination, and calls `CGImageDestinationFinalize` to write the multi-frame package.

#### Vector-Preserving PDF Conversion (`NSGraphicsContext` + SVG)
- For standard bitmap sources, the engine creates a `CGContext` PDF page and draws the bitmap `CGImage` into it.
- For vector SVG sources, standard bitmap drawing would pixelate the output. The engine instead:
  1. Loads the vector asset natively via `NSImage(contentsOf:)`.
  2. Creates a `CGContext` pointing to the target PDF file.
  3. Wraps the PDF `CGContext` inside an AppKit `NSGraphicsContext` configured for flipped coordinate rendering.
  4. Natively draws the vector layout using `NSImage.draw(in:)` within the graphics context boundaries, which captures and embeds vector lines directly in the PDF file.

#### SVG Pre-Rasterization (`SVGRasterizer`)
- SVG files must be rasterized to bitmap PNGs before converting them to WebP, JPEG, PNG, ICNS, or ICO formats.
- The `SVGRasterizer` loads the SVG file via `NSImage`, reads its natural vector dimensions, and scales the target size preserving its aspect ratio (capped at a maximum dimension of `2048px`).
- Creates a `CGContext` and binds it to a temporary `NSGraphicsContext`.
- Draws the SVG vector to render a bitmap into the context, extracts a `CGImage`, writes it to a temporary PNG file (`dragon_svg_<UUID>.png`), and feeds the temp file into the conversion pipeline. The temporary file is deleted immediately after the conversion job completes.

#### Overwrite Policies
Before starting conversion, the destination path is evaluated against overwrite rules:
- **Overwrite**: Deletes any existing file at the path and writes the new file.
- **Skip**: Aborts the operation and throws an `overwriteBlocked` error.
- **Auto-Rename**: Sequentially checks paths appending `(1)`, `(2)`, etc. (e.g., `Image (1).webp`) to locate a unique filename.

#### Output Verification
Every successfully converted file is checked for integrity before reporting a success state to the UI:
1. *Existence Check*: Verifies the file actually exists on the filesystem.
2. *Empty File Check*: Verifies the file size is greater than 0 bytes.
3. *Format-Specific Header Checks*:
   - **PNG, JPEG, WebP**: Verifies the file is loadable via `CGImageSourceCreateWithURL` and has a frame count > 0.
   - **ICNS**: Verifies the file starts with the ASCII signature `"icns"`.
   - **ICO**: Verifies the binary begins with the Microsoft icon signature bytes `[0x00, 0x00, 0x01, 0x00]`.
   - **PDF**: Verifies the document starts with the PDF marker signature bytes `"%PDF"`.
