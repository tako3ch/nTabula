# nTabula データフロー図

**作成日**: 2026-03-16
**更新日**: 2026-03-16（kairo-design によるヒアリング反映）
**関連アーキテクチャ**: [architecture.md](architecture.md)
**関連要件定義**: [requirements.md](../../spec/ntabula/requirements.md)

**【信頼性レベル凡例】**:
- 🔵 **青信号**: EARS要件定義書・設計文書・ユーザヒアリングを参考にした確実なフロー
- 🟡 **黄信号**: EARS要件定義書・設計文書・ユーザヒアリングから妥当な推測によるフロー
- 🔴 **赤信号**: EARS要件定義書・設計文書・ユーザヒアリングにない推測によるフロー

---

## 1. テキスト入力フロー 🔵

**信頼性**: 🔵 *EditorView.swift Coordinator・AppState.updateContent()より*

**関連要件**: REQ-003, REQ-113, REQ-301, NFR-001, NFR-002

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant TV as NTTextView
    participant C as Coordinator
    participant AS as AppState
    participant PM as PersistenceManager

    U->>TV: テキスト入力
    TV->>TV: hasMarkedText() チェック
    alt IME 変換中 (REQ-113)
        TV-->>U: シンタックスHL再計算スキップ
    else 確定済み
        TV->>C: textDidChange()
        C->>AS: updateContent(string, tabID)
        AS->>AS: tabs[idx].content = string, isDirty = true
        C->>C: scheduleAutoSave() (3秒 debounce REQ-301)
        C-->>PM: saveTabs() ← 3秒後
    end
```

---

## 2. Notion 保存フロー (Cmd+S) 🔵

**信頼性**: 🔵 *nTabulaApp.swift・MainWindowView.swift・AppState.syncActiveTab()より*

**関連要件**: REQ-103, REQ-106, REQ-109, REQ-110, REQ-111, REQ-112, REQ-201

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant TV as NTTextView
    participant NC as NotificationCenter
    participant MW as MainWindowView
    participant AS as AppState
    participant MTN as MarkdownToNotion
    participant NS as NotionService
    participant NOTION as Notion API

    U->>TV: Cmd+S
    TV->>NC: post(.ntSaveDocument)
    NC->>MW: onReceive
    MW->>AS: syncActiveTab()

    AS->>AS: isDirty チェック (false & 保存済み → skip REQ-106)

    AS->>MTN: convert(tab.content)
    MTN-->>AS: [[String: Any]] blocks

    alt 既存ページ更新 (REQ-112)
        AS->>NS: updatePageContent(pageID, title, propName, blocks)
        NS->>NOTION: PATCH /pages/{id} (タイトル更新)
        NS->>NOTION: GET /blocks/{id}/children
        NS->>NOTION: DELETE /blocks/{blockID} (全削除 REQ-406)
        NS->>NOTION: PATCH /blocks/{id}/children (追加)
        NOTION-->>NS: NotionPage
    else 新規 DB ページ (REQ-111)
        AS->>NS: createPage(databaseID, title, propName, blocks)
        NS->>NOTION: POST /pages
        NOTION-->>NS: NotionPage
    else 新規 子ページ (REQ-111)
        AS->>NS: createSubPage(pageID, title, blocks)
        NS->>NOTION: POST /pages
        NOTION-->>NS: NotionPage
    end

    NS-->>AS: NotionPage
    AS->>AS: markSaved(tabID, pageID, titlePropertyName)
    AS->>AS: isDirty = false
```

---

## 3. タブ切り替えフロー 🔵

**信頼性**: 🔵 *EditorView.swift updateNSView()より*

**関連要件**: REQ-202, NFR-002

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant TB as TabBarView / SidebarView
    participant AS as AppState
    participant EV as EditorView (updateNSView)
    participant TV as NTTextView

    U->>TB: タブをクリック
    TB->>AS: activeTabID = tab.id
    AS-->>EV: @Observable 更新通知
    EV->>EV: currentTabID != activeTabID ?
    EV->>TV: textView.string = newContent
    EV->>TV: storage.rehighlight()
    EV->>EV: currentTabID = activeTabID
```

---

## 4. グローバルホットキーフロー (Ctrl+Shift+N) 🔵

**信頼性**: 🔵 *HotKeyService.swift・AppDelegate.swiftより*

**関連要件**: REQ-101, REQ-102

```mermaid
sequenceDiagram
    participant OS as macOS
    participant HK as HotKeyService
    participant AD as AppDelegate
    participant WIN as NSWindow

    OS->>HK: Carbon EventHandler (Ctrl+Shift+N)
    HK->>AD: onHotKeyPressed()
    AD->>WIN: isVisible && isKeyWindow ?
    alt ウィンドウ前面 (REQ-102)
        AD->>WIN: orderOut() (非表示)
    else ウィンドウ後面・非表示 (REQ-101)
        AD->>WIN: makeKeyAndOrderFront() (前面へ)
    end
```

---

## 5. 設定変更フロー 🔵

**信頼性**: 🔵 *SettingsView.swift・AppState.updateNotionToken()より*

**関連要件**: REQ-301, REQ-302, REQ-303, REQ-403, NFR-101, NFR-103

```mermaid
flowchart TD
    A[SettingsView 操作] --> B{設定種別}

    B -->|フォント変更| C[appState.editorFontName = value]
    C --> D[PersistenceManager.saveFontName]
    C --> E[EditorView.updateNSView: resolvedFont 更新]

    B -->|トークン保存 SecureField| F[appState.updateNotionToken]
    F --> G[PersistenceManager.saveToken → Keychain 書き込み]
    F --> H[notionService.updateToken]
    F --> I[fetchDatabases / fetchPages]

    B -->|DB 選択| J[appState.selectedDatabaseID = id]
    J --> K[PersistenceManager.saveSelectedDatabaseID]

    B -->|保存先タイプ| L[appState.notionSaveTarget = .page/.database]
    L --> M[PersistenceManager.saveNotionSaveTarget]

    B -->|レイアウト切り替え| N[appState.tabLayoutMode = .vertical/.horizontal]
    N --> O[PersistenceManager.saveTabLayoutMode]
    N --> P[MainWindowView: アニメーションで切り替え]
```

---

## 6. 状態管理フロー 🔵

**信頼性**: 🔵 *AppState.swift・PersistenceManagerより*

**関連要件**: REQ-001, REQ-002, REQ-005

```mermaid
flowchart LR
    subgraph AppState ["AppState (@Observable)"]
        T[tabs: TabItem]
        AID[activeTabID]
        NST[notionSaveTarget]
        DB[selectedDatabaseID]
        PP[selectedParentPageID]
        UI[tabLayoutMode / fontSize etc]
    end

    subgraph Views
        MW[MainWindowView]
        EV[EditorView]
        TB[TabBarView]
        SB[VerticalSidebarView]
        ST[SettingsView]
    end

    AppState -->|@Environment 読み取り| Views
    Views -->|メソッド呼び出し| AppState
    AppState -->|PersistenceManager| UD[(UserDefaults\nタブ・設定)]
    AppState -->|PersistenceManager| KC[(Keychain\nNotionToken)]
```

---

## 7. エラーハンドリングフロー 🔵

**信頼性**: 🔵 *AppState.swift・MainWindowView.swiftより*

**関連要件**: EDGE-001, NFR-201

```mermaid
flowchart TD
    A[syncActiveTab 実行] --> B{API 呼び出し}
    B -->|成功| C[markSaved → isDirty = false]
    B -->|NotionAPIError| D[syncError = error.localizedDescription]
    D --> E[StatusBar に赤テキスト表示]
    E --> F[ユーザーが内容を確認・修正]
    F --> G[再度 Cmd+S で再試行]
```

---

## 8. Keychain トークン移行フロー（新規） 🔵

**信頼性**: 🔵 *REQ-403・ユーザヒアリング 2026-03-16 起動時自動移行確認より*

**関連要件**: REQ-403, NFR-101

```mermaid
sequenceDiagram
    participant APP as アプリ起動
    participant AS as AppState.init()
    participant PM as PersistenceManager
    participant KC as Keychain
    participant UD as UserDefaults

    APP->>AS: 初期化開始
    AS->>PM: loadToken()
    PM->>KC: SecItemCopyMatching (Keychain 検索)
    alt Keychain にトークンあり
        KC-->>PM: token
        PM-->>AS: token (移行不要)
    else Keychain にトークンなし
        KC-->>PM: errSecItemNotFound
        PM->>UD: string(forKey: "nTabula.notionToken")
        alt UserDefaults にトークンあり（既存ユーザー）
            UD-->>PM: token
            PM->>KC: SecItemAdd (Keychain に保存)
            PM->>UD: removeObject(forKey:) (UserDefaults から削除)
            PM-->>AS: token (移行完了)
        else 両方なし（新規ユーザー）
            PM-->>AS: "" (未設定)
        end
    end
    AS->>AS: notionToken = token
```

---

## 9. Cmd+W タブ閉じフロー（新規） 🔵

**信頼性**: 🔵 *REQ-105・ユーザヒアリング 2026-03-16 Cmd+W確認より*

**関連要件**: REQ-105, REQ-108, EDGE-002, EDGE-003

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant CMD as Commands (nTabulaApp)
    participant AS as AppState

    U->>CMD: Cmd+W
    CMD->>AS: closeTab(activeTab)
    AS->>AS: isPinned チェック (REQ-108)
    alt ピン留めタブ
        AS-->>CMD: 何もしない（削除禁止）
    else 通常タブ
        AS->>AS: tabs から削除
        AS->>AS: 前のタブ or 次のタブを activeTabID に設定 (EDGE-003)
        alt 全タブ削除
            AS->>AS: activeTabID = nil (EDGE-002)
        end
        AS->>AS: saveTabs()
    end
```

---

## 10. タブ D&D 並び替えフロー（新規） 🔵

**信頼性**: 🔵 *REQ-305・ユーザヒアリング 2026-03-16 D&Dアプローチ確認より*

**関連要件**: REQ-305

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant TV as TabBarView / VerticalSidebarView
    participant AS as AppState

    U->>TV: タブをドラッグ開始
    TV->>TV: .draggable(tab.id) 起動
    U->>TV: ドロップ先にドロップ
    TV->>TV: .dropDestination(for: UUID.self)
    TV->>AS: moveTab(draggedID:toAfterID:)
    AS->>AS: isPinned 境界チェック
    alt ピン ↔ 非ピン 間の移動
        AS-->>TV: 移動拒否（アニメーションで元に戻る）
    else 同ゾーン内の移動
        AS->>AS: tabs 配列を更新 (fromOffsets:toOffset:)
        AS->>AS: saveTabs()
        AS-->>TV: @Observable 更新通知 → UI 反映
    end
```

---

## 11. テスト注入アーキテクチャ（新規） 🔵

**信頼性**: 🔵 *NFR-301・NFR-302・ユーザヒアリング 2026-03-16 Unit Test確認より*

**関連要件**: NFR-301, NFR-302, NFR-303

```mermaid
flowchart TD
    subgraph "本番環境"
        NS_P["NotionService\ninit(token: String,\nsession: URLSession = .shared)"]
        PM_P["PersistenceManager\ninit(defaults: UserDefaults = .standard)"]
    end

    subgraph "テスト環境 (nTabulaTests)"
        MOCK_URL["MockURLProtocol\n(URLProtocol サブクラス)"]
        TEST_UD["UserDefaults\n(suiteName: UUID)"]
        NS_T["NotionService\ninit(token: 'test',\nsession: mockSession)"]
        PM_T["PersistenceManager\ninit(defaults: testDefaults)"]
    end

    MOCK_URL --> NS_T
    TEST_UD --> PM_T
    NS_T --> |モックレスポンス検証| NOTION_MOCK["Notion APIモック"]
    PM_T --> |ストレージ分離| STORE_MOCK["独立した UserDefaults"]
```

---

## 信頼性レベルサマリー

- 🔵 青信号: 11件 (100%)
- 🟡 黄信号: 0件 (0%)
- 🔴 赤信号: 0件 (0%)

**品質評価**: ✅ 高品質（実装コード + ユーザヒアリングで全件確認済み）
