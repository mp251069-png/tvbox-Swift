import Foundation
import Testing
@testable import TVBox

@Suite("HGhubX 原生短剧数据")
struct ShortDramaServiceTests {
    @Test("feed 信封能解出短剧卡片、分页与剧集")
    func decodesFeedEnvelope() throws {
        let data = Data(#"""
        {
          "status": 1,
          "data": {
            "items": [{
              "id": 42,
              "title": "测试短剧",
              "cover": "https://images.example/cover.jpg",
              "description": "简介",
              "tags": ["都市"],
              "score": 9.2,
              "episode_count": 12,
              "total_episodes": 12,
              "is_finished": true,
              "episodes": [{"ep_num": 1, "title": "第1集", "duration": 60, "status": 1}]
            }],
            "pagination": {"page": 1, "pages": 3, "size": 24, "total": 55}
          }
        }
        """#.utf8)

        let page = try ShortDramaService.decodePayload(ShortDramaPage.self, from: data)
        #expect(page.items.count == 1)
        #expect(page.items[0].id == 42)
        #expect(page.items[0].title == "测试短剧")
        #expect(page.items[0].episodeCount == 12)
        #expect(page.items[0].episodes.first?.epNum == 1)
        #expect(page.pagination?.pages == 3)
    }

    @Test("edge 失败状态返回上游错误")
    func rejectsFailedEnvelope() {
        let data = Data(#"{"status":0,"msg":"接口返回失败"}"#.utf8)
        #expect(throws: ShortDramaServiceError.self) {
            try ShortDramaService.decodePayload(ShortDramaPage.self, from: data)
        }
    }

    @Test("播放响应优先使用主流并兼容 HEVC")
    func selectsPlaybackStream() throws {
        let data = Data(#"{"data":{"video_url":"","streams":{"main":"https://cdn.example/main.m3u8","hevc":"https://cdn.example/hevc.m3u8"}}}"#.utf8)
        let response = try ShortDramaService.decodePayload(ShortDramaPlayback.self, from: data)
        #expect(response.preferredURL == "https://cdn.example/main.m3u8")
        #expect(response.candidateURLs.count == 2)

        let hevcData = Data(#"{"video_url_hevc":"https://cdn.example/old-hevc.m3u8"}"#.utf8)
        let hevcResponse = try ShortDramaService.decodePayload(ShortDramaPlayback.self, from: hevcData)
        #expect(hevcResponse.preferredURL == "https://cdn.example/old-hevc.m3u8")
    }

    @Test("服务地址只接受纯 HTTPS origin")
    func validatesServerOrigin() {
        #expect(ShortDramaService.normalizeOrigin("https://EXAMPLE.com/") == "https://example.com")
        #expect(ShortDramaService.normalizeOrigin("http://example.com") == nil)
        #expect(ShortDramaService.normalizeOrigin("https://example.com/api") == nil)
        #expect(ShortDramaService.normalizeOrigin("https://user@example.com") == nil)
    }

    @Test("播放 URL 必须是 HTTP(S) 且不能带账号信息")
    func validatesPlaybackURL() {
        #expect(ShortDramaService.isHTTPURL("https://cdn.example/episode.m3u8?token=abc"))
        #expect(!ShortDramaService.isHTTPURL("javascript:alert(1)"))
        #expect(!ShortDramaService.isHTTPURL("https://user@cdn.example/video.m3u8"))
    }
}
