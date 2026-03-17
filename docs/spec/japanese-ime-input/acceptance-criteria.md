# 日本語 IME 入力 受け入れ基準

**作成日**: 2026-03-16
**関連要件定義**: [requirements.md](requirements.md)
**関連ユーザストーリー**: [user-stories.md](user-stories.md)
**ヒアリング記録**: [interview-record.md](interview-record.md)

**【信頼性レベル凡例】**:
- 🔵 **青信号**: 既存実装・設計文書・ユーザヒアリングを参考にした確実な基準
- 🟡 **黄信号**: 既存実装・設計文書から妥当な推測による基準
- 🔴 **赤信号**: 推測による基準

---

## REQ-IME-101: IME 変換中の AppState 更新スキップ 🔵

**信頼性**: 🔵 *EditorView.Coordinator.textDidChange L109より*

### Given（前提条件）
- nTabula エディタにフォーカスがある
- macOS 日本語 IME が有効

### When（実行条件）
- `hasMarkedText() == true` の状態で `textDidChange` が発火する

### Then（期待結果）
- `appState.updateContent()` が呼ばれない
- `scheduleAutoSave()` が呼ばれない
- AppState の `tabs` 配列が変更されない

### テストケース

#### 正常系

- [ ] **TC-IME-001-01**: IME 変換中の textDidChange スキップ 🔵
  - **入力**: hasMarkedText() == true のとき textDidChange 通知
  - **期待結果**: appState.updateContent() が 0 回呼ばれる
  - **テスト種別**: Unit Test（Coordinator をモックで検証）
  - **信頼性**: 🔵 *EditorView.swift L109より*

- [ ] **TC-IME-001-02**: IME 確定後の textDidChange 正常処理 🔵
  - **入力**: hasMarkedText() == false のとき textDidChange 通知
  - **期待結果**: appState.updateContent() が 1 回呼ばれる
  - **テスト種別**: Unit Test
  - **信頼性**: 🔵 *EditorView.swift L110より*

---

## REQ-IME-103: IME 変換中のシンタックスハイライトスキップ 🔵

**信頼性**: 🔵 *MarkdownTextStorage.processEditing() L229-230より*

### Given（前提条件）
- MarkdownTextStorage が textView と接続されている

### When（実行条件）
- `textView.hasMarkedText() == true` の状態で `processEditing()` が呼ばれる

### Then（期待結果）
- `applyHighlighting()` が呼ばれない
- IME マーキング属性（下線など）が破壊されない

### テストケース

#### 正常系

- [ ] **TC-IME-103-01**: IME 変換中のハイライトスキップ 🔵
  - **入力**: textView.hasMarkedText() == true で processEditing() 呼び出し
  - **期待結果**: applyHighlighting() が呼ばれない
  - **テスト種別**: Unit Test
  - **信頼性**: 🔵 *EditorView.swift L229より*

- [ ] **TC-IME-103-02**: IME 変換確定後のハイライト正常適用 🔵
  - **入力**: textView.hasMarkedText() == false で processEditing() 呼び出し
  - **期待結果**: applyHighlighting() が呼ばれる
  - **テスト種別**: Unit Test
  - **信頼性**: 🔵 *EditorView.swift L229-233より*

#### 境界値

- [ ] **TC-IME-103-B01**: textView が nil の場合の安全な動作 🔵
  - **入力**: textView == nil で processEditing() 呼び出し
  - **期待結果**: `textView?.hasMarkedText() != true` → true なのでハイライト実行（クラッシュなし）
  - **テスト種別**: Unit Test
  - **信頼性**: 🔵 *EditorView.swift L229（`!= true` パターン）より*

---

## REQ-IME-104 / REQ-IME-105: タブ切り替え時の textView.string 更新制御 🔵

**信頼性**: 🔵 *EditorView.updateNSView() L68-74より*

### Given（前提条件）
- 2つ以上のタブが存在する

### When（実行条件）
- 同一タブ内で updateNSView が呼ばれる

### Then（期待結果）
- `textView.string` が上書きされない
- IME マーキングが維持される

### When（別の実行条件）
- タブ切り替えで updateNSView が呼ばれる（activeTabID が変わった場合）

### Then（期待結果）
- `textView.string` が新しいタブのコンテンツで更新される
- `rehighlight()` が呼ばれる

### テストケース

#### 正常系

- [ ] **TC-IME-104-01**: 同一タブ内での textView.string 非更新 🔵
  - **入力**: currentTabID == activeTabID の状態で updateNSView 呼び出し
  - **期待結果**: textView.string が変更されない
  - **テスト種別**: Unit Test
  - **信頼性**: 🔵 *EditorView.swift L69より*

- [ ] **TC-IME-105-01**: タブ切り替え時の textView.string 更新 🔵
  - **入力**: currentTabID != activeTabID の状態で updateNSView 呼び出し
  - **期待結果**: textView.string == 新しいタブのコンテンツ
  - **テスト種別**: Unit Test
  - **信頼性**: 🔵 *EditorView.swift L70-73より*

---

## REQ-IME-106: IME 変換中の Cmd+S 同期 🔵

**信頼性**: 🔵 *NTTextView.keyDown・ユーザヒアリング 2026-03-16より*

### Given（前提条件）
- Notion Integration Token が設定済み
- 保存先が設定済み

### When（実行条件）
- IME 変換中（hasMarkedText() == true）に Cmd+S を押す

### Then（期待結果）
- `ntSaveDocument` 通知が送信される
- `appState.syncActiveTab()` が呼ばれる
- エラーなしで Notion 同期が実行される

### テストケース

#### 正常系

- [ ] **TC-IME-106-01**: Cmd+S イベントが IME 中でも発火する 🔵
  - **入力**: Cmd+S キーイベント（hasMarkedText 状態に関係なく）
  - **期待結果**: ntSaveDocument 通知が 1 回発火する
  - **テスト種別**: Unit Test（NTTextView.keyDown 検証）
  - **信頼性**: 🔵 *NTTextView.keyDown L131-133より*

---

## NFR-IME-001: テキストの整合性 🔵

**信頼性**: 🔵 *AC-005 既存受け入れ基準より*

### テストケース（XCUITest）

- [ ] **TC-IME-NFR-01**: IME 変換確定後にテキストが保持される 🔵
  - **手順**:
    1. エディタに「にほんご」を入力（IME 変換候補表示）
    2. Return で確定
    3. エディタのテキストを確認
  - **期待結果**: 確定したテキスト（例: 「日本語」）がエディタに表示される
  - **テスト種別**: XCUITest
  - **信頼性**: 🔵 *AC-005 基準2より*

- [ ] **TC-IME-NFR-02**: 複数回の IME 変換後もテキスト整合性が保たれる 🟡
  - **手順**:
    1. 10回連続で日本語変換確定を行う
    2. 最終テキストを確認
  - **期待結果**: すべての確定テキストがエディタに正しく残る
  - **テスト種別**: XCUITest
  - **信頼性**: 🟡 *AC-005の一般化から推測*

---

## NFR-IME-003: タブ切り替え時の変換キャンセル 🔵

**信頼性**: 🔵 *ユーザヒアリング 2026-03-16より*

### テストケース

- [ ] **TC-IME-NFR-03-01**: IME 変換中のタブ切り替えで新タブが正しく表示される 🔵
  - **手順**:
    1. タブ A で IME 変換中
    2. タブ B をクリック
    3. エディタのコンテンツを確認
  - **期待結果**: タブ B のコンテンツが表示される（タブ A の未確定テキストは破棄）
  - **テスト種別**: XCUITest
  - **信頼性**: 🔵 *EditorView.updateNSView()・ユーザヒアリングより*

---

## EDGE-IME-001 / EDGE-IME-002: エッジケース

### テストケース

- [ ] **TC-IME-EDGE-01**: textView nil 時のクラッシュなし 🔵
  - **入力**: MarkdownTextStorage.textView = nil の状態で processEditing() 呼び出し
  - **期待結果**: クラッシュなし、ハイライトが適用される（`!= true` 評価のため）
  - **テスト種別**: Unit Test
  - **信頼性**: 🔵 *EditorView.swift L229のガード条件より*

- [ ] **TC-IME-EDGE-02**: Cmd+S 時の未確定テキスト処理 🟡
  - **入力**: IME マーキング中に Cmd+S
  - **期待結果**: 同期が完了する（未確定テキストが含まれる場合でもエラーにならない）
  - **テスト種別**: XCUITest（手動確認）
  - **信頼性**: 🟡 *ユーザヒアリングから推測*

---

## テストケースサマリー

### カテゴリ別件数

| カテゴリ | 正常系 | 異常系 | 境界値 | 合計 |
|---------|--------|--------|--------|------|
| 機能要件 | 7 | 0 | 1 | 8 |
| 非機能要件 | 3 | 0 | 0 | 3 |
| Edgeケース | 0 | 2 | 0 | 2 |
| **合計** | **10** | **2** | **1** | **13** |

### テスト種別別件数

| 種別 | 件数 | 備考 |
|------|------|------|
| Unit Test | 8 | xCTest で自動化可能 |
| XCUITest | 5 | IME 操作には XCUITest が必要 |

### 信頼性レベル分布

- 🔵 青信号: 11件 (85%)
- 🟡 黄信号: 2件 (15%)
- 🔴 赤信号: 0件 (0%)

**品質評価**: ✅ 高品質

### 優先度別テストケース

- **Must Have**: 13件（全件）
- **Should Have**: 0件
- **Could Have**: 0件

---

## テスト実施計画

### Phase 1: Unit Test（TASK-0009 以降）
- TC-IME-001-01, TC-IME-001-02
- TC-IME-103-01, TC-IME-103-02, TC-IME-103-B01
- TC-IME-104-01, TC-IME-105-01
- TC-IME-106-01
- TC-IME-EDGE-01

### Phase 2: XCUITest（将来）
- TC-IME-NFR-01, TC-IME-NFR-02
- TC-IME-NFR-03-01
- TC-IME-EDGE-02

> **注意**: XCUITest は macOS IME のシミュレートが必要なため、CI 環境での自動化には追加設定が必要。
