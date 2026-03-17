# nTabula

A macOS markdown editor that saves notes directly to Notion.

> 日本語版は [README.ja.md](README.ja.md) を参照してください。

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Swift](https://img.shields.io/badge/swift-5.9-orange)

## Features

- **Markdown editor** with syntax highlighting (headings, bold, italic, code, links, etc.)
- **Tabbed interface** — horizontal or vertical (Arc-style) tab layout
- **Pin tabs** — pinned tabs persist across restarts
- **Save to Notion** — converts Markdown to Notion blocks automatically
- **Auto-save** — saves locally 3 seconds after typing stops
- **Global hotkey** — `Ctrl+Shift+N` to show/hide the window from anywhere
- **Window state memory** — remembers size and position
- **Dark / Light mode** support

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15 or later (to build from source)
- A [Notion Integration Token](https://www.notion.so/my-integrations)

## Download

Download the latest `.dmg` from the [Releases](../../releases) page.

## Build from Source

### 1. Create Xcode Project

1. Xcode → File → New → Project
2. Select **macOS > App**
3. Configure:
   - Product Name: `nTabula`
   - Bundle Identifier: `jp.umi.design.nTabula`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Use Core Data: OFF / Include Tests: OFF

### 2. Add Source Files

Delete the auto-generated `ContentView.swift` and `Assets.xcassets`, then add all files under `Sources/`:

```
Sources/App/       → nTabulaApp.swift, AppDelegate.swift, AppState.swift
Sources/Models/    → TabItem.swift, NotionModels.swift
Sources/Services/  → NotionService.swift, HotKeyService.swift
Sources/Views/     → MainWindowView.swift, EditorView.swift, TabBarView.swift,
                     VerticalSidebarView.swift, SettingsView.swift
Sources/Utilities/ → MarkdownToNotion.swift, PersistenceManager.swift
```

### 3. Configure Info.plist

- Target → Build Settings → set `Info.plist File` to `Resources/Info.plist`

### 4. Configure Entitlements

- Target → Signing & Capabilities → Add:
  - **App Sandbox**
  - **Outgoing Connections (Client)**
- Set Entitlements File to `Resources/nTabula.entitlements`

### 5. Add Carbon.framework

- Target → General → Frameworks, Libraries → `+` → search `Carbon.framework`

### 6. Set Deployment Target

- Target → General → Minimum Deployments: **macOS 14.0**

### 7. Build and Run

```
Cmd+R
```

## Notion Setup

1. Go to [Notion Integrations](https://www.notion.so/my-integrations)
2. Create a new integration
3. Open your Notion database → Connect to the integration
4. Enter the Integration Token in nTabula's Settings

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+N` | Show / hide window (global) |
| `Cmd+S` | Save to Notion |
| `Cmd+T` | New tab |

## Tech Stack

- Swift / SwiftUI + AppKit (macOS 14+)
- Notion REST API (Integration Token auth)
- No external dependencies

## License

MIT — see [LICENSE](LICENSE)

## Author

[umi.design](https://umi.design)
