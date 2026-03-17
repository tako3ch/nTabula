# 日本語 IME 入力 要件定義書

**機能名**: 日本語 IME 入力
**要件名**: japanese-ime-input
**作成日**: 2026-03-16

## 概要

macOS の日本語 IME（Input Method Editor）を使って日本語を入力する際に、テキストが壊れたり消えたりしないことを保証する。具体的には、IME 変換中（マーキング状態）の間はシステムがテキストへの副作用処理（AppState 更新・シンタックスハイライト再計算・textView.string 上書き）を一切行わないよう制御する。

## 関連文書

- **ヒアリング記録**: [💬 interview-record.md](interview-record.md)
- **ユーザストーリー**: [📖 user-stories.md](user-stories.md)
- **受け入れ基準**: [✅ acceptance-criteria.md](acceptance-criteria.md)
- **コンテキストノート**: [📝 note.md](note.md)
- **既存要件（ntabula）**: [📋 ../ntabula/requirements.md](../ntabula/requirements.md)（REQ-113）

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 **青信号**: 既存実装・既存設計文書・ユーザヒアリングを参考にした確実な要件
- 🟡 **黄信号**: 既存実装・設計文書から妥当な推測による要件
- 🔴 **赤信号**: 推測による要件

### 通常要件

- REQ-IME-001: システムは NSTextView の `hasMarkedText()` API を使って IME 変換中を検出しなければならない 🔵 *EditorView.swift L109, L229より*
- REQ-IME-002: システムは IME 変換中でない場合、テキスト変更を AppState に反映しなければならない 🔵 *EditorView.Coordinator.textDidChange L106-111より*
- REQ-IME-003: システムは IME 変換中でない場合、自動保存デバウンスを発火しなければならない 🔵 *scheduleAutoSave() L111より*

### 条件付き要件

- REQ-IME-101: `hasMarkedText() == true` の場合、システムは `appState.updateContent()` の呼び出しをスキップしなければならない 🔵 *EditorView.swift L109より*
- REQ-IME-102: `hasMarkedText() == true` の場合、システムは `scheduleAutoSave()` の呼び出しをスキップしなければならない 🔵 *EditorView.swift L109より（早期リターンによる副作用）*
- REQ-IME-103: `hasMarkedText() == true` の場合、システムはシンタックスハイライトの再計算（`applyHighlighting()`）をスキップしなければならない 🔵 *MarkdownTextStorage.processEditing() L229-230より*
- REQ-IME-104: SwiftUI の `updateNSView` が呼ばれた際に同一タブ内の場合、システムは `textView.string` を上書きしてはならない 🔵 *EditorView.updateNSView() L68-74より*
- REQ-IME-105: タブが切り替わった場合、システムは `textView.string` を新しいタブのコンテンツで差し替えなければならない 🔵 *EditorView.updateNSView() L69-74より*
- REQ-IME-106: `Cmd+S` が押された場合、IME 変換中であっても システムはその時点のテキストで Notion 同期を実行しなければならない 🔵 *ユーザヒアリング 2026-03-16より*

### 状態要件

- REQ-IME-201: IME 変換中の状態にある場合、システムはマーキング属性（下線・強調表示）を NSTextView の通常 IME 表示として維持しなければならない 🔵 *EditorView.swift L229（上書きしないことで実現）より*
- REQ-IME-202: IME 変換確定後の状態に移行した時点で、システムは次の `textDidChange` コールで AppState へのコンテンツ反映を再開しなければならない 🔵 *EditorView.Coordinator.textDidChange L109-111より*

### 制約要件

- REQ-IME-401: システムは macOS 日本語 IME のみを対象とし、中国語・韓国語 IME の動作保証はスコープ外とする 🔵 *ユーザヒアリング 2026-03-16より*
- REQ-IME-402: システムは `MarkdownTextStorage.textView` を `weak var` で保持し、循環参照を防がなければならない 🔵 *EditorView.swift L201より*

## 非機能要件

### ユーザビリティ

- NFR-IME-001: IME 変換中に入力テキストが消えたり文字化けしたりしてはならない 🔵 *US-006・AC-005より*
- NFR-IME-002: IME 変換の確定操作（Return / スペースキー / 候補クリック）後、テキストは正しく確定されなければならない 🔵 *AC-005 基準2より*
- NFR-IME-003: IME 変換中のタブ切り替えは変換をキャンセルして新しいタブを表示しなければならない 🔵 *ユーザヒアリング 2026-03-16より*

### パフォーマンス

- NFR-IME-101: `hasMarkedText()` チェックは O(1) で完了しなければならない 🔵 *macOS NSTextView APIの仕様より（同期・軽量）*

### 保守性

- NFR-IME-201: `hasMarkedText()` チェックは `textDidChange`（Coordinator）と `processEditing`（MarkdownTextStorage）の両方に独立して実装しなければならない 🔵 *EditorView.swift 既存実装より（防御的二重チェック）*

## Edgeケース

### エラー処理

- EDGE-IME-001: `textView` が nil になっている場合、`MarkdownTextStorage.processEditing()` は IME チェックを `!= true` で行うため安全に動作する 🔵 *EditorView.swift L229より（`textView?.hasMarkedText() != true`）*
- EDGE-IME-002: IME 変換中に `appState.activeTabID` が nil になった場合、`textDidChange` の先頭 guard で早期リターンし、IME チェックより前に処理を終了する 🔵 *EditorView.swift L106-107より*

### 境界値

- EDGE-IME-101: 入力文字がすべてひらがな・カタカナ（変換不要）の場合でも、IME を通じた入力は `hasMarkedText()` が一時的に true になる可能性がある 🟡 *macOS IME の一般的な動作から推測*
- EDGE-IME-102: `Cmd+S` で同期した際に IME 変換中のマーキングテキストが含まれている場合、Notion には未確定テキストが含まれた状態で保存される 🟡 *NTTextView.keyDown の実装から推測*

---

## EARS要件・設計文書との対応関係

**参照した機能要件**:
- REQ-113（既存）: IME 変換中のシンタックスハイライトスキップ → REQ-IME-103 として詳細化

**参照した非機能要件**:
- US-006: 日本語でストレスなく書く → NFR-IME-001, NFR-IME-002 として具体化

**参照したEdgeケース**:
- AC-005 の4項目を EDGE-IME として整理

**参照した設計文書**:
- `Sources/Views/EditorView.swift` — Coordinator.textDidChange, updateNSView, MarkdownTextStorage.processEditing
- `docs/spec/ntabula/acceptance-criteria.md` — AC-005
- `docs/spec/ntabula/user-stories.md` — US-006

---

## 品質評価

| 評価項目 | 判定 |
|---------|------|
| 要件の曖昧さ | なし |
| 入出力定義の完全性 | 完全 |
| 制約条件の明確性 | 明確 |
| 実装可能性 | 確実（既実装） |
| 信頼性レベル分布 | 🔵 青信号 87%、🟡 黄信号 13% |

**品質評価**: ✅ 高品質

### 信頼性レベルサマリー

- 🔵 **青信号**: 13項目 (87%)
- 🟡 **黄信号**: 2項目 (13%)
- 🔴 **赤信号**: 0項目 (0%)
