import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// HGhubX 短剧只读 API。采用原生 URLSession，不依赖 Tauri、Rust 或 WebView。
final class ShortDramaService {
    static let shared = ShortDramaService()
    static let defaultOrigin = "https://huangguoai.com"
    static let serverPreferenceKey = "hghubx.shortDrama.serverOrigin"

    private let session: URLSession
    private init(session: URLSession = .shared) {
        self.session = session
    }

    var currentOrigin: String {
        let saved = UserDefaults.standard.string(forKey: Self.serverPreferenceKey) ?? Self.defaultOrigin
        return Self.normalizeOrigin(saved) ?? Self.defaultOrigin
    }

    /// 只接受 HTTPS origin，避免把 API 请求发到任意路径、明文 HTTP 或带凭据的 URL。
    static func normalizeOrigin(_ rawValue: String) -> String? {
        guard var components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            return nil
        }
        components.scheme = "https"
        components.host = host.lowercased()
        components.path = ""
        return components.string?.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func saveOrigin(_ rawValue: String) throws {
        guard let origin = Self.normalizeOrigin(rawValue) else {
            throw ShortDramaServiceError.invalidServerAddress
        }
        UserDefaults.standard.set(origin, forKey: Self.serverPreferenceKey)
    }

    func resetOrigin() {
        UserDefaults.standard.removeObject(forKey: Self.serverPreferenceKey)
    }

    func fetchFeed(page: Int = 1, size: Int = 24) async throws -> ShortDramaPage {
        let data = try await request(path: "/api/videos", queryItems: [
            URLQueryItem(name: "page", value: String(max(page, 1))),
            URLQueryItem(name: "size", value: String(min(max(size, 1), 40)))
        ])
        return try Self.decodePayload(ShortDramaPage.self, from: data)
    }

    func search(_ query: String, page: Int = 1, size: Int = 24) async throws -> ShortDramaPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await fetchFeed(page: page, size: size) }
        let data = try await request(path: "/api/search", queryItems: [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page", value: String(max(page, 1))),
            URLQueryItem(name: "size", value: String(min(max(size, 1), 40))),
            URLQueryItem(name: "type", value: "video")
        ])
        return try Self.decodePayload(ShortDramaPage.self, from: data)
    }

    func detail(id: Int) async throws -> ShortDramaVideo {
        let data = try await request(path: "/api/videos/\(id)")
        return try Self.decodePayload(ShortDramaVideo.self, from: data)
    }

    /// 优先调用 HGhubX 当前的 playback POST 接口；旧接口只作一次只读回退。
    /// 返回 main/旧字段/HEVC 的候选 URL，播放器失败时可由用户切换备用流。
    func playbackURLs(videoID: Int, episode: Int) async throws -> [String] {
        var firstError: Error?
        do {
            let data = try await request(
                path: "/api/videos/\(videoID)/episodes/\(episode)/playback",
                method: "POST",
                body: Data("{}".utf8)
            )
            let response = try Self.decodePayload(ShortDramaPlayback.self, from: data)
            let candidates = Self.validPlaybackURLs(response.candidateURLs)
            if !candidates.isEmpty { return candidates }
            firstError = ShortDramaServiceError.noPlayableAddress
        } catch {
            firstError = error
        }

        do {
            let data = try await request(path: "/api/videos/\(videoID)/play", queryItems: [
                URLQueryItem(name: "ep", value: String(episode)),
                URLQueryItem(name: "page_texts", value: "0")
            ])
            let response = try Self.decodePayload(ShortDramaPlayback.self, from: data)
            let candidates = Self.validPlaybackURLs(response.candidateURLs)
            if !candidates.isEmpty { return candidates }
        } catch {
            if firstError == nil { firstError = error }
        }
        throw firstError ?? ShortDramaServiceError.noPlayableAddress
    }

    /// 读取封面并兼容 HGhubX 使用的 AES-128-CBC 图片响应。
    func coverData(from rawURL: String) async throws -> Data {
        guard let url = resourceURL(rawURL) else { throw ShortDramaServiceError.invalidResourceURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("image/jpeg,image/png,image/gif,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(currentOrigin + "/", forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ShortDramaServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ShortDramaServiceError.httpStatus(http.statusCode) }
        if Self.imageMIME(for: data) != nil { return data }
        guard let decoded = Self.decryptCover(data), Self.imageMIME(for: decoded) != nil else {
            throw ShortDramaServiceError.coverDecodeFailed
        }
        return decoded
    }

    /// 解开 HGhubX edge API 的 {"status": 1, "data": ...} 外层；也兼容直返 payload。
    static func decodePayload<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let payload: Any
        if let dictionary = root as? [String: Any] {
            let message = (dictionary["msg"] as? String) ?? (dictionary["message"] as? String) ?? ""
            if let rawStatus = dictionary["status"] {
                guard let status = (rawStatus as? NSNumber)?.intValue ?? Int(String(describing: rawStatus)),
                      status == 1 else {
                    throw ShortDramaServiceError.upstream(message)
                }
            }
            if let wrapped = dictionary["data"], !(wrapped is NSNull) {
                payload = wrapped
            } else {
                payload = dictionary
            }
        } else {
            payload = root
        }

        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.fragmentsAllowed])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: payloadData)
        } catch {
            throw ShortDramaServiceError.invalidResponse
        }
    }

    static func isHTTPURL(_ rawValue: String) -> Bool {
        guard let components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else {
            return false
        }
        return true
    }

    private static func validPlaybackURLs(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        return candidates.filter { isHTTPURL($0) && seen.insert($0).inserted }
    }

    /// 复用 HGhubX Tauri 客户端的 edge 请求协议：JSON envelope POST，业务 body 使用 Base64。
    private func request(path: String, queryItems: [URLQueryItem] = [], method: String = "GET", body: Data? = nil) async throws -> Data {
        guard var endpoint = URLComponents(string: currentOrigin),
              var edge = URLComponents(string: currentOrigin) else {
            throw ShortDramaServiceError.invalidServerAddress
        }
        endpoint.path = path
        endpoint.queryItems = queryItems.isEmpty ? nil : queryItems
        let endpointPath = endpoint.percentEncodedPath + (endpoint.percentEncodedQuery.map { "?\($0)" } ?? "")
        edge.path = "/api/edge/request"
        edge.queryItems = nil
        guard let edgeURL = edge.url else { throw ShortDramaServiceError.invalidServerAddress }

        let envelope: [String: Any] = [
            "method": method,
            "path": endpointPath,
            "body": body?.base64EncodedString() ?? "",
            "content_type": body == nil ? "" : "application/json"
        ]
        let envelopeData = try JSONSerialization.data(withJSONObject: envelope)
        var request = URLRequest(url: edgeURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.httpBody = envelopeData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(currentOrigin + "/", forHTTPHeaderField: "Referer")
        request.setValue("TVBox-Swift short-drama client", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ShortDramaServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.message(in: data)
            if !message.isEmpty { throw ShortDramaServiceError.upstream(message) }
            throw ShortDramaServiceError.httpStatus(http.statusCode)
        }
        return data
    }

    private func resourceURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: URL?
        if trimmed.hasPrefix("//") {
            candidate = URL(string: "https:\(trimmed)")
        } else if let absolute = URL(string: trimmed), absolute.scheme != nil {
            candidate = absolute
        } else {
            candidate = URL(string: trimmed, relativeTo: URL(string: currentOrigin))?.absoluteURL
        }
        guard let candidate, Self.isHTTPURL(candidate.absoluteString) else { return nil }
        return candidate
    }

    private static func message(in data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        return (root["msg"] as? String) ?? (root["message"] as? String) ?? ""
    }

    private static func imageMIME(for data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF { return "image/jpeg" }
        if bytes.count >= 8 && bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "image/png" }
        if bytes.count >= 6 && String(bytes: bytes.prefix(6), encoding: .ascii)?.hasPrefix("GIF8") == true { return "image/gif" }
        if bytes.count >= 12 && bytes[0...3].elementsEqual(Array("RIFF".utf8)) && bytes[8...11].elementsEqual(Array("WEBP".utf8)) { return "image/webp" }
        return nil
    }

    private static func decryptCover(_ encrypted: Data) -> Data? {
        guard !encrypted.isEmpty, encrypted.count.isMultiple(of: 16) else { return nil }
        #if canImport(CommonCrypto)
        let key = Data("f5d965df75336270".utf8)
        let iv = Data("97b60394abc2fbe1".utf8)
        var output = Data(count: encrypted.count + kCCBlockSizeAES128)
        var moved = 0
        let status: CCCryptorStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                encrypted.withUnsafeBytes { inputBytes in
                    output.withUnsafeMutableBytes { outputBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            kCCKeySizeAES128,
                            ivBytes.baseAddress,
                            inputBytes.baseAddress,
                            encrypted.count,
                            outputBytes.baseAddress,
                            outputBytes.count,
                            &moved
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return Data(output.prefix(moved))
        #else
        return nil
        #endif
    }
}
