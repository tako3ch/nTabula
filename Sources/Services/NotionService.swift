import Foundation

actor NotionService {
    private var integrationToken: String
    private let baseURL = "https://api.notion.com/v1"
    private let notionVersion = "2022-06-28"
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(token: String) {
        self.integrationToken = token
    }

    func updateToken(_ token: String) {
        self.integrationToken = token
    }

    // MARK: - Public API

    /// Integration に共有されているデータベース一覧を取得
    func fetchDatabases() async throws -> [NotionDatabase] {
        let body: [String: Any] = [
            "filter": ["value": "database", "property": "object"],
            "page_size": 100
        ]
        let req = try makeRequest(path: "/search", method: "POST", body: body)
        let response: NotionListResponse<NotionDatabase> = try await perform(req)
        return response.results
    }

    /// 指定データベースに新規ページを作成
    func createPage(databaseID: String, title: String, titlePropertyName: String, blocks: [[String: Any]]) async throws -> NotionPage {
        let body: [String: Any] = [
            "parent": ["database_id": databaseID],
            "properties": [
                titlePropertyName: ["title": [["text": ["content": title]]]]
            ],
            "children": blocks
        ]
        let req = try makeRequest(path: "/pages", method: "POST", body: body)
        return try await perform(req)
    }

    /// 指定ページの子ページを作成
    func createSubPage(pageID: String, title: String, blocks: [[String: Any]]) async throws -> NotionPage {
        let body: [String: Any] = [
            "parent": ["page_id": pageID],
            "properties": [
                "title": ["title": [["text": ["content": title]]]]
            ],
            "children": blocks
        ]
        let req = try makeRequest(path: "/pages", method: "POST", body: body)
        return try await perform(req)
    }

    /// 既存ページのタイトルとコンテンツを更新（既存ブロックを全削除して再追加）
    func updatePageContent(pageID: String, title: String, titlePropertyName: String, blocks: [[String: Any]]) async throws -> NotionPage {
        // タイトル更新
        let titleBody: [String: Any] = [
            "properties": [
                titlePropertyName: ["title": [["text": ["content": title]]]]
            ]
        ]
        let titleReq = try makeRequest(path: "/pages/\(pageID)", method: "PATCH", body: titleBody)
        let page: NotionPage = try await perform(titleReq)

        // 既存ブロックを全削除
        let existingBlocks = try await getBlockChildren(pageID: pageID)
        for block in existingBlocks {
            try await deleteBlock(id: block.id)
        }

        // 新規ブロックを追加
        if !blocks.isEmpty {
            try await appendBlocks(pageID: pageID, blocks: blocks)
        }

        return page
    }

    /// Integration に共有されているページ一覧を取得
    func fetchPages() async throws -> [NotionPageItem] {
        let body: [String: Any] = [
            "filter": ["value": "page", "property": "object"],
            "page_size": 100
        ]
        let req = try makeRequest(path: "/search", method: "POST", body: body)
        let response: NotionListResponse<NotionPageItem> = try await perform(req)
        return response.results
    }

    // MARK: - Private Helpers

    private func getBlockChildren(pageID: String) async throws -> [NotionBlockResult] {
        let req = try makeRequest(path: "/blocks/\(pageID)/children", method: "GET", body: nil)
        let response: NotionBlockChildrenResponse = try await perform(req)
        return response.results
    }

    private func deleteBlock(id: String) async throws {
        let req = try makeRequest(path: "/blocks/\(id)", method: "DELETE", body: nil)
        let _: IgnoredResponse = try await perform(req)
    }

    private func appendBlocks(pageID: String, blocks: [[String: Any]]) async throws {
        let body: [String: Any] = ["children": blocks]
        let req = try makeRequest(path: "/blocks/\(pageID)/children", method: "PATCH", body: body)
        let _: IgnoredResponse = try await perform(req)
    }

    private func makeRequest(path: String, method: String, body: [String: Any]?) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(integrationToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if !(200...299).contains(http.statusCode) {
            if let apiError = try? decoder.decode(NotionAPIError.self, from: data) {
                throw apiError
            }
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(T.self, from: data)
    }
}

private struct IgnoredResponse: Sendable {}
extension IgnoredResponse: Decodable {
    nonisolated init(from decoder: any Decoder) throws {}
}
