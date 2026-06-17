<p align="center">
  <a href="https://drag-on.app">

  <img src="https://github.com/user-attachments/assets/ffff2249-d06d-479b-8c34-f203d485db47" alt="Drag.on Banner" width="100%">
    </a>
</p>

<h1 align="center">Drag.on</h1>

<p align="center">
  A magical drag-and-drop shelf for macOS.<br>
  Store files, summon them anywhere, and convert images instantly.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.6+-blue">
  <img src="https://img.shields.io/badge/Swift-6-orange">
  <img src="https://img.shields.io/badge/License-MIT-green">
</p>



## Features

### Summon Your Lair

Drag any file and perform a quick shake gesture.

The Lair instantly appears beside your cursor, ready to receive files.

* Global shake detection
* Adjustable summon position
* Adjustable summon distance
* Floating always-on-top interface

---

### Temporary File Shelf

Store files while working across applications.

Perfect for:

* Designers moving assets between apps
* Developers organizing project files
* Content creators managing exports
* Anyone tired of desktop clutter

Features:

* Drag files in
* Drag files back out
* Persistent storage between launches
* Restore previous Lair contents
* Browser image drops
* Folder support

---

### Lair Management Mode

Need more control?

Switch to the Lair Manager to view all stored items in a clean grid layout.

* Multi-selection support
* Batch operations
* Open files
* Reveal in Finder
* Convert images
* Delete files
* Native multi-file drag and drop

---

### Built-in Image Converter

Convert images directly from your shelf.

Supported output formats:

| Format | Supported |
| ------ | --------- |
| WebP   | Yes       |
| PNG    | Yes       |
| JPEG   | Yes       |
| PDF    | Yes       |
| ICO    | Yes       |
| ICNS   | Yes       |

Additional features:

* Quality controls
* Custom output locations
* Same-folder exports
* Downloads exports
* Custom destination folders
* SVG support
* Batch conversion

Converted files can be automatically added back to the Lair for immediate use.

---

### ⌘ Global Productivity Shortcuts

Configure custom keyboard shortcuts for:

* Toggle Lair
* Import from Clipboard
* Restore Previous Lair

---

### Built for macOS

Drag.on is designed specifically for macOS and embraces native platform technologies.

* SwiftUI
* AppKit
* Native drag-and-drop
* Vibrancy effects
* Quick Look thumbnails
* Menu bar integration
* Launch at login support

---

## Screenshots

Add screenshots here.

| Lair       | Manager    | Converter  |
| ---------- | ---------- | ---------- |
| <img width="612" height="652" alt="lair screenshot" src="https://github.com/user-attachments/assets/85cea7c3-9c86-482a-9abb-0b362f6b770d" />| <img width="1132" height="692" alt="manager screenshot" src="https://github.com/user-attachments/assets/5484fb1a-5b1f-4a3a-9ce9-1cd571e2db99" />| <img width="852" height="1052" alt="convert panle screenshot" src="https://github.com/user-attachments/assets/c6bace3f-fa2d-481d-b592-b0d79454e462" />|

---

## Installation

### Download Release

Download the latest DMG from the Releases page.

1. Download the latest release
2. Open the DMG
3. Drag Drag.on into Applications
4. Launch the app
5. Grant any requested permissions

### If macOS Blocks the App

If Drag.on still cannot be opened:

1. Open **System Settings**.
2. Navigate to **Privacy & Security**.
3. Scroll down to the **Security** section.
4. Locate the message indicating that Drag.on was blocked.
5. Click **Open Anyway**.
6. Confirm when prompted.


### Build from Source

Requirements:

* macOS 14.6+
* Xcode 16+
* Swift 6

```bash
git clone https://github.com/YOUR_USERNAME/drag.on.git

cd drag.on

open drag.on.xcodeproj
```

Build and run from Xcode.

---

## How It Works

1. Start dragging a file.
2. Shake left and right.
3. The Lair appears.
4. Drop files onto the shelf.
5. Continue working.
6. Drag files back out whenever needed.

For images:

1. Add images to the Lair.
2. Press Convert.
3. Choose a format.
4. Convert.
5. Drag the results anywhere.

---

## Settings

### General

* Launch at Login
* Preferred Terminal
* Web Drops Folder
* Shake Sensitivity
* Summon Position
* Summon Distance

### Conversion

* Default Format
* Output Location

### Appearance

* Compact Mode
* Cloud Animations
* Theme Selection

### Shortcuts

* Toggle Lair
* Open Clipboard
* Restore Previous Lair

---

## Tech Stack

* Swift 6
* SwiftUI
* AppKit
* UserDefaults
* QuickLook Thumbnail Generator
* WebP
* SIPS
* iconutil

---

## Acknowledgements

Drag.on wouldn't be possible without these open-source projects:

### [Keyboard Shortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

Keyboard shortcut recording and global hotkey handling.

### [Launch At Login](https://github.com/sindresorhus/LaunchAtLogin-Modern)

Launch the application automatically at login.

### [libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode)

WebP encoding and conversion support.

### [TourKit](https://github.com/rampatra/TourKit)

Inspiration for the onboarding experience.

---

## License

MIT License

Feel free to use, modify, and contribute.

---

Made with love, snow, and a little dragon magic.

