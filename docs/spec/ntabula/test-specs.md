# nTabula テスト仕様書（逆生成）

## 分析概要

**分析日時**: 2026-03-16
**対象コードベース**: Sources/
**テストカバレッジ**: 0%（テスト未実装）
**生成テストケース数**: 52 個
**実装推奨テスト数**: 52 個

---

## 現在のテスト実装状況

### テストフレームワーク
- **単体テスト**: XCTest（未実装）
- **統合テスト**: XCTest（未実装）
- **UI テスト**: XCUITest（未実装）
- **テストターゲット**: Xcode プロジェクトにテストターゲット未追加

### テストカバレッジ詳細

| ファイル | 行カバレッジ | 分岐カバレッジ | 備考 |
|---------|------------|-------------|------|
| Sources/Utilities/MarkdownToNotion.swift | 0% | 0% | 純粋関数・最優先 |
| Sources/Utilities/PersistenceManager.swift | 0% | 0% | UserDefaults ラッパー |
| Sources/App/AppState.swift | 0% | 0% | 状態管理ロジック |
| Sources/Models/TabItem.swift | 0% | 0% | Codable 検証 |
| Sources/Models/NotionModels.swift | 0% | 0% | Decodable 検証 |
| Sources/Services/NotionService.swift | 0% | 0% | API クライアント（要モック） |
| **全体** | **0%** | **0%** | |

---

## テストカテゴリ別 実装推奨状況

### 単体テスト (Unit Tests)
- [ ] MarkdownToNotion — ブロック変換ロジック
- [ ] MarkdownToNotion — インライン Rich Text 変換
- [ ] TabItem — Codable encode/decode
- [ ] TabItem — `derivedTitle` 生成
- [ ] NotionModels — NotionDatabase JSON デコード (titlePropertyName 抽出)
- [ ] NotionModels — NotionPageItem JSON デコード
- [ ] AppState — タブ CRUD ロジック
- [ ] AppState — `generateDefaultTitle()` 連番生成
- [ ] AppState — `syncActiveTab()` isDirty スキップロジック

### 統合テスト (Integration Tests)
- [ ] NotionService — API モックを使ったページ作成フロー
- [ ] NotionService — API モックを使ったページ更新フロー
- [ ] AppState + NotionService — `syncActiveTab()` の E2E フロー（モック）
- [ ] PersistenceManager — タブ保存・復元サイクル

### UI テスト (XCUITest)
- [ ] タブ作成・切り替え・削除
- [ ] タイトル編集
- [ ] 設定画面の表示

---

## テスト優先順位

### 高優先度（即座に実装推奨）

1. **MarkdownToNotion** — 純粋関数で外部依存なし、最も実装しやすく効果が高い
2. **TabItem Codable** — UserDefaults 永続化の信頼性に直結
3. **NotionModels Decodable** — titlePropertyName の誤解決が実際のバグとなった前例あり
4. **AppState タブ管理** — コアビジネスロジック

### 中優先度
5. **NotionService** — URLSession モックで API テスト
6. **PersistenceManager** — `UserDefaults.standard` を差し替えてテスト

### 低優先度
7. **UI テスト** — XCUITest のセットアップコストが高い

---

## テスト環境設定

### Xcode テストターゲット追加手順

```
Xcode > File > New > Target > Unit Testing Bundle
Bundle ID: jp.umi.design.nTabulaTests
Host Application: nTabula
```

### 推奨ファイル構成

```
nTabulaTests/
├── Utilities/
│   ├── MarkdownToNotionTests.swift      ← 最優先
│   └── PersistenceManagerTests.swift
├── Models/
│   ├── TabItemTests.swift
│   └── NotionModelsTests.swift
├── App/
│   └── AppStateTests.swift
└── Services/
    └── NotionServiceTests.swift         ← URLSession モック必要
```

### URLSession モック戦略

`NotionService` は `URLSession.shared` をハードコードしているため、
テスト時は `URLSession` をプロトコル化 or `URLProtocol` サブクラスでインターセプトする。

```swift
// URLProtocol を使ったモック方法（推奨）
class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: HTTPURLResponse?
    static var mockError: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocol(self, didReceiveResponse: MockURLProtocol.mockResponse!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: MockURLProtocol.mockData ?? Data())
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```
