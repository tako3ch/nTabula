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
- A [Notion Integration Token](https://www.notion.so/my-integrations)

## Download

Download the latest `.dmg` from the [Releases](../../releases) page, open it, and drag nTabula.app to your Applications folder.

## Notion Setup

1. Go to [Notion Integrations](https://www.notion.so/my-integrations)
2. Create a new integration
3. Open your Notion database → Connect to the integration
4. Enter the Integration Token in nTabula's Settings

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+N` | Show / hide window (global, configurable) |
| `Cmd+S` | Save to Notion |
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Cmd+Shift+T` | Restore closed tab |
| `Cmd+P` | Toggle preview |
| `Cmd+Shift+E` | Export as Markdown file |
| `Cmd+,` | Open Settings |
| `Cmd+1` … `Cmd+9` | Switch to tab by number |

## Tech Stack

- Swift / SwiftUI + AppKit (macOS 14+)
- Notion REST API (Integration Token auth)
- No external dependencies

## License

MIT — see [LICENSE](LICENSE)

## Author

[umi.design](https://umi.design)
