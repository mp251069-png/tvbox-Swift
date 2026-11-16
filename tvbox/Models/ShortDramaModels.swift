import Foundation

/// HGhubX 的访客短剧列表与详情数据。只保留原生浏览、剧集选择和播放所需字段。
struct ShortDramaVideo: Decodable, Identifiable {
    let id: Int
    let title: String
    let cover: String
    let summary: String
    let tags: [String]
    let score: Double
    let episodeCount: Int
    let totalEpisodes: Int
    let isFinished: Bool
    let episodes: [ShortDramaEpisode]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case cover
        case description
        case tags
        case score
        case episodeCount
        case totalEpisodes
        case isFinished
        case episodes
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        if let titleValue = try values.decodeIfPresent(String.self, forKey: .title) {
            title = titleValue
        } else if let nameValue = try values.decodeIfPresent(String.self, forKey: .name) {
            title = nameValue
        } else {
            title = "未命名短剧"
        }
        cover = try values.decodeIfPresent(String.self, forKey: .cover) ?? ""
        summary = try values.decodeIfPresent(String.self, forKey: .description) ?? ""
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        score = try values.decodeIfPresent(Double.self, forKey: .score) ?? 0
        episodeCount = try values.decodeIfPresent(Int.self, forKey: .episodeCount) ?? 0
        totalEpisodes = try values.decodeIfPresent(Int.self, forKey: .totalEpisodes) ?? episodeCount
        isFinished = try values.decodeIfPresent(Bool.self, forKey: .isFinished) ?? false
        episodes = try values.decodeIfPresent([ShortDramaEpisode].self, forKey: .episodes) ?? []
    }
}

struct ShortDramaEpisode: Decodable, Identifiable, Hashable {
    let epNum: Int
    let title: String
    let duration: Int
    let status: Int

    var id: Int { epNum }

    init(epNum: Int, title: String, duration: Int, status: Int) {
        self.epNum = epNum
        self.title = title
        self.duration = duration
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case epNum
        case title
        case duration
        case status
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        epNum = try values.decodeIfPresent(Int.self, forKey: .epNum) ?? 1
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "第\(epNum)集"
        duration = try values.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        status = try values.decodeIfPresent(Int.self, forKey: .status) ?? 0
    }
}

struct ShortDramaPagination: Decodable {
    let page: Int?
    let pages: Int?
    let size: Int?
    let total: Int?
}

struct ShortDramaPage: Decodable {
    let items: [ShortDramaVideo]
    let pagination: ShortDramaPagination?

    enum CodingKeys: String, CodingKey {
        case items
        case pagination
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decodeIfPresent([ShortDramaVideo].self, forKey: .items) ?? []
        pagination = try values.decodeIfPresent(ShortDramaPagination.self, forKey: .pagination)
    }
}

struct ShortDramaPlayback: Decodable {
    struct Streams: Decodable {
        let main: String?
        let hevc: String?
    }

    let videoUrl: String?
    let videoUrlHevc: String?
    let streams: Streams?

    enum CodingKeys: String, CodingKey {
        case videoUrl
        case videoUrlHevc
        case streams
    }

    var candidateURLs: [String] {
        var seen = Set<String>()
        return [streams?.main, videoUrl, streams?.hevc, videoUrlHevc]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    var preferredURL: String? {
        candidateURLs.first
    }
}

enum ShortDramaServiceError: LocalizedError {
    case invalidServerAddress
    case invalidResourceURL
    case invalidResponse
    case httpStatus(Int)
    case upstream(String)
    case noPlayableAddress
    case coverDecodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidServerAddress:
            return "服务地址必须是 HTTPS 主机地址，不要带路径或账号信息"
        case .invalidResourceURL:
            return "上游返回的资源地址无效"
        case .invalidResponse:
            return "上游响应格式无法识别"
        case .httpStatus(let status):
            return "短剧服务请求失败（HTTP \(status)）"
        case .upstream(let message):
            return message.isEmpty ? "短剧服务暂时不可用" : message
        case .noPlayableAddress:
            return "上游没有返回可播放的视频地址"
        case .coverDecodeFailed:
            return "封面无法解码"
        }
    }
}
