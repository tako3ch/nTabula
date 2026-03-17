# nTabula

Notion にマークダウンを保存できる macOS メモアプリ。

## 必要環境

- macOS 14.0 (Sonoma) 以上
- Xcode 15 以上

## Xcode プロジェクトのセットアップ

### 1. プロジェクト作成

1. Xcode → File → New → Project
2. **macOS > App** を選択
3. 設定:
   - Product Name: `nTabula`
   - Bundle Identifier: `jp.umi.design.nTabula`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Use Core Data: OFF / Include Tests: OFF

### 2. ソースファイルの追加

自動生成された `ContentView.swift` と `Assets.xcassets` を削除後、`Sources/` 以下のファイルをすべて追加。

```
Sources/App/      → nTabulaApp.swift, AppDelegate.swift, AppState.swift
Sources/Models/   → TabItem.swift, NotionModels.swift
Sources/Services/ → NotionService.swift, HotKeyService.swift
Sources/Views/    → MainWindowView.swift, EditorView.swift, TabBarView.swift,
                    VerticalSidebarView.swift, SettingsView.swift
Sources/Utilities/→ MarkdownToNotion.swift, PersistenceManager.swift
```

### 3. Info.plist の差し替え

- Target → Build Settings → `Info.plist File` を `Resources/Info.plist` に変更
- または自動生成 Info.plist に同等の設定を追加

### 4. Entitlements の設定

- Target → Signing & Capabilities → Capability を追加
  - **App Sandbox**（自動で .entitlements が生成される）
  - **Outgoing Connections (Client)**（Network: Client を ON）
- 既存 .entitlements を `Resources/nTabula.entitlements` の内容で上書き、またはターゲットの Entitlements File に `Resources/nTabula.entitlements` を指定

### 5. Carbon.framework の追加

- Target → General → Frameworks, Libraries → `+`
- `Carbon.framework` を検索して追加

### 6. Deployment Target

- Target → General → Minimum Deployments: **macOS 14.0**

### 7. ビルドと実行

```
Cmd+R で起動
```

## Notion Integration Token の取得

1. [Notion Integrations](https://www.notion.so/my-integrations) にアクセス
2. 「新しいインテグレーション」を作成
3. 使用したいデータベースのページ → 「接続」→ 作成したインテグレーションを追加
4. アプリの設定画面でトークンを入力

## キーボードショートカット

| ショートカット | 動作 |
|---|---|
| `Ctrl+Shift+N` | アプリ起動 / フォーカス切り替え（グローバル） |
| `Cmd+S` | Notion に保存 |
| `Cmd+T` | 新規タブ |

## 機能

- マークダウンシンタックスハイライト（見出し/太字/コード/リンクなど）
- タブ式エディタ（横タブ / 縦タブ切り替え）
- ピン留めタブ（再起動後も保持）
- Notion データベースへの保存（マークダウンを Notion ブロックに変換）
- 自動保存（入力後 3 秒、ローカルのみ）
- ウィンドウサイズ・位置の記憶
- ダーク / ライトモード対応
