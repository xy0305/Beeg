import Foundation

struct BeegVideo: Identifiable, Hashable {
    let id: Int
    let title: String
    let duration: Int
    let width: Int
    let height: Int
    let views: Int
    let likes: Int
    let created: String
    let thumbs: [Int]
    let ownerName: String
    let ownerSlug: String
    let ownerAvatar: URL?

    var route: String { "/-0\(id)" }
    var aspect: CGFloat {
        guard width > 0, height > 0 else { return 16.0 / 9.0 }
        return CGFloat(width) / CGFloat(height)
    }
}

struct BeegTag: Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String
    let kind: String
    let avatar: URL?

    var displayName: String { BeegCatalog.displayName(name) }
}

enum BeegAPIError: LocalizedError {
    case invalidResponse
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Beeg 返回了无法识别的数据"
        case .rejected(let message): return message
        }
    }
}

final class BeegClient {
    static let store = URL(string: "https://store.externulls.com")!
    static let thumbs = URL(string: "https://thumbs.externulls.com")!
    static let searchSocket = URL(string: "wss://search.externulls.com")!

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "Referer": "https://beeg.com/",
            "Origin": "https://beeg.com",
            "Accept": "application/json"
        ]
        configuration.timeoutIntervalForRequest = 25
        self.session = session == .shared ? URLSession(configuration: configuration) : session
    }

    func home(offset: Int) async throws -> [BeegVideo] {
        try await videos(url: endpoint("/facts/tag", [
            "slug": "index",
            "limit": "\(BeegCatalog.pageSize)",
            "offset": "\(offset)"
        ]))
    }

    func videos(slug: String, offset: Int) async throws -> [BeegVideo] {
        let safe = slug.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !safe.isEmpty else { throw BeegAPIError.rejected("无效标签") }
        return try await videos(url: endpoint("/tag/videos/\(safe)", [
            "limit": "\(BeegCatalog.pageSize)",
            "offset": "\(offset)"
        ]))
    }

    func recommends(type: String) async throws -> [BeegTag] {
        guard ["person", "brand", "other"].contains(type) else { throw BeegAPIError.rejected("无效推荐类型") }
        let data = try await data(for: endpoint("/tag/recommends", ["type": type, "slug": "index"]))
        let rows = try decoder.decode([RawTag].self, from: data)
        return rows.compactMap(BeegTag.init)
    }

    func searchTags(query: String) async throws -> [BeegTag] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { return [] }
        let payload: [String: Any] = [
            "type": "search",
            "ignore_stats": true,
            "payload": ["Search_string": trimmed, "offset": 0, "limit": 24]
        ]
        let message = try await SearchSocket.shared.request(payload)
        let rows = try decoder.decode([RawSearchTag].self, from: Data(message.utf8))
        return rows.compactMap(BeegTag.init)
    }

    func playbackURL(fileID: Int) async throws -> URL {
        var request = URLRequest(url: endpoint("/video/play_url/\(fileID)"))
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        guard let template = String(data: data, encoding: .utf8),
              let master = BeegCatalog.masterPlaylist(template: template, fileID: fileID) else {
            throw BeegAPIError.invalidResponse
        }
        var playlistRequest = URLRequest(url: master)
        playlistRequest.setValue("*/*", forHTTPHeaderField: "Accept")
        playlistRequest.setValue("https://beeg.com/", forHTTPHeaderField: "Referer")
        playlistRequest.setValue("https://beeg.com", forHTTPHeaderField: "Origin")
        let (playlistData, playlistResponse) = try await session.data(for: playlistRequest)
        try validate(playlistResponse)
        guard let playlist = String(data: playlistData, encoding: .utf8),
              let variant = BeegCatalog.preferredVariant(playlist) else {
            return master
        }
        return URL(string: "https://video.beeg.com\(variant)") ?? master
    }

    static func avatarURL(photoID: Int?, cropID: Int?) -> URL? {
        guard let photoID, let cropID else { return nil }
        return URL(string: "\(thumbs.absoluteString)/photos/\(photoID)/to.webp?crop_id=\(cropID)&size_new=128x128")
    }

    static func frameURL(fileID: Int, second: Int, width: Int = 960) -> URL {
        let height = max(1, width * 9 / 16)
        return URL(string: "\(thumbs.absoluteString)/videos/\(fileID)/\(max(0, second)).webp?size=\(width)x\(height)")!
    }

    private func videos(url: URL) async throws -> [BeegVideo] {
        let rows = try decoder.decode([RawFact].self, from: try data(for: url))
        return rows.compactMap(BeegVideo.init)
    }

    private func data(for url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        try validate(response)
        return data
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BeegAPIError.invalidResponse
        }
    }

    private func endpoint(_ path: String, _ query: [String: String] = [:]) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "store.externulls.com"
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }
}

private struct RawFact: Decodable {
    let fcFacts: [RawPublish]?
    let file: RawFile
    let tags: [RawOwner]?

    enum CodingKeys: String, CodingKey {
        case fcFacts = "fc_facts"
        case file, tags
    }
}

private struct RawPublish: Decodable {
    let created: String?
    let views: Int?
    let likes: Int?
    let publicLikes: Int?
    let thumbs: [Int]?

    enum CodingKeys: String, CodingKey {
        case created = "fc_created"
        case views = "fc_st_views"
        case likes = "reactions_count"
        case publicLikes = "reactions_count_unreg"
        case thumbs = "fc_thumbs"
    }
}

private struct RawFile: Decodable {
    let data: [RawColumn]?
    let duration: Int?
    let width: Int?
    let height: Int?
    let id: Int

    enum CodingKeys: String, CodingKey {
        case data
        case duration = "fl_duration"
        case width = "fl_width"
        case height = "fl_height"
        case id
    }
}

private struct RawColumn: Decodable {
    let column: String?
    let value: String?

    enum CodingKeys: String, CodingKey {
        case column = "cd_column"
        case value = "cd_value"
    }
}

private struct RawOwner: Decodable {
    let id: Int
    let owner: Bool?
    let name: String?
    let slug: String?
    let thumbs: [RawThumb]?

    enum CodingKeys: String, CodingKey {
        case id
        case owner = "is_owner"
        case name = "tg_name"
        case slug = "tg_slug"
        case thumbs
    }
}

private struct RawThumb: Decodable {
    let id: Int
    let crops: [RawCrop]?
}

private struct RawCrop: Decodable {
    let id: Int
}

private struct RawTag: Decodable {
    let id: Int
    let name: String
    let slug: String
    let thumbs: [RawThumb]?

    enum CodingKeys: String, CodingKey {
        case id
        case name = "tg_name"
        case slug = "tg_slug"
        case thumbs
    }
}

private struct RawSearchTag: Decodable {
    let id: Int
    let name: String
    let slug: String
    let type: String?
    let thumbs: [RawThumb]?

    enum CodingKeys: String, CodingKey {
        case id
        case name = "tg_name"
        case slug = "tg_slug"
        case type = "Tg_type"
        case thumbs
    }
}

private extension BeegVideo {
    init?(_ raw: RawFact) {
        guard raw.file.id > 0 else { return nil }
        let publish = raw.fcFacts?.first
        let owner = raw.tags?.first { $0.owner == true } ?? raw.tags?.first
        let crop = owner?.thumbs?.first?.crops?.first
        id = raw.file.id
        title = raw.file.data?.first { $0.column == "sf_name" }?.value ?? "Untitled"
        duration = raw.file.duration ?? 0
        width = raw.file.width ?? 0
        height = raw.file.height ?? 0
        views = publish?.views ?? 0
        likes = (publish?.likes ?? 0) + (publish?.publicLikes ?? 0)
        created = publish?.created ?? ""
        thumbs = publish?.thumbs ?? []
        ownerName = owner?.name ?? ""
        ownerSlug = owner?.slug ?? ""
        ownerAvatar = BeegClient.avatarURL(photoID: owner?.thumbs?.first?.id, cropID: crop?.id)
    }
}

private extension BeegTag {
    init?(_ raw: RawTag) {
        guard !raw.slug.isEmpty else { return nil }
        let crop = raw.thumbs?.first?.crops?.first
        self.init(id: raw.id, name: raw.name, slug: raw.slug, kind: "channel", avatar: BeegClient.avatarURL(photoID: raw.thumbs?.first?.id, cropID: crop?.id))
    }

    init?(_ raw: RawSearchTag) {
        guard !raw.slug.isEmpty else { return nil }
        let crop = raw.thumbs?.first?.crops?.first
        self.init(id: raw.id, name: raw.name, slug: raw.slug, kind: raw.type ?? "tag", avatar: BeegClient.avatarURL(photoID: raw.thumbs?.first?.id, cropID: crop?.id))
    }
}

private final class SearchSocket: NSObject, URLSessionWebSocketDelegate {
    static let shared = SearchSocket()
    private var socket: URLSessionWebSocketTask?
    private var continuation: CheckedContinuation<String, Error>?
    private let lock = NSLock()

    func request(_ payload: [String: Any]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation?.resume(throwing: CancellationError())
            self.continuation = continuation
            self.pendingPayload = payload
            let task = makeSocket()
            socket = task
            lock.unlock()
            task.resume()
            Task {
                try await Task.sleep(nanoseconds: 8_000_000_000)
                self.finish(.failure(BeegAPIError.rejected("搜索超时")))
            }
        }
    }

    private var pendingPayload: [String: Any]?

    private func sendPending() {
        lock.lock()
        let payload = pendingPayload
        pendingPayload = nil
        let task = socket
        lock.unlock()
        guard let payload, let task else { return }
        Task {
            do {
                let data = try JSONSerialization.data(withJSONObject: payload)
                try await task.send(.string(String(decoding: data, as: UTF8.self)))
                let message = try await task.receive()
                let text: String
                switch message {
                case .string(let value): text = value
                case .data(let value): text = String(decoding: value, as: UTF8.self)
                @unknown default: text = "[]"
                }
                finish(.success(text))
                task.cancel(with: .normalClosure, reason: nil)
            } catch {
                finish(.failure(error))
            }
        }
    }

    private func makeSocket() -> URLSessionWebSocketTask {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        var request = URLRequest(url: BeegClient.searchSocket)
        request.setValue("https://beeg.com", forHTTPHeaderField: "Origin")
        return session.webSocketTask(with: request)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        sendPending()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        finish(Result.failure(BeegAPIError.invalidResponse))
    }
}

private extension SearchSocket {
    func finish(_ result: Result<String, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
