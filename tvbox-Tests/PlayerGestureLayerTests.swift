import Testing
import Foundation
import AVFoundation
@testable import TVBox

/// Property-based tests for PlayerGestureLayer.computeSeekTarget.
/// These tests validate that seek target computation is correctly clamped.
///
/// **Validates: Requirements 1.2, 1.3, 1.5, 1.6**

// MARK: - Property 1: Seek target computation is correctly clamped

/// For any currentTime t ∈ [0, duration], any offset (positive or negative, large or small),
/// and duration d > 0, computeSeekTarget returns a value in [0, d].
@Suite("Property 1: Seek target computation is correctly clamped")
struct SeekTargetClampingTests {

    @Test("Seek target is always within [0, duration] for randomized inputs")
    func seekTargetAlwaysClamped() {
        for _ in 0..<200 {
            let duration = Double.random(in: 0.001...36000.0)
            let currentTime = Double.random(in: 0...duration)
            let offset = Double.random(in: -100000...100000)

            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: currentTime,
                offset: offset,
                duration: duration
            )

            #expect(
                result >= 0,
                "Seek target \(result) should be >= 0 (currentTime=\(currentTime), offset=\(offset), duration=\(duration))"
            )
            #expect(
                result <= duration,
                "Seek target \(result) should be <= duration \(duration) (currentTime=\(currentTime), offset=\(offset))"
            )
        }
    }

    @Test("Seek target clamps to 0 when offset is very negative")
    func seekTargetClampsToZero() {
        for _ in 0..<100 {
            let duration = Double.random(in: 1.0...10000.0)
            let currentTime = Double.random(in: 0...duration)
            // Offset guaranteed to pull below zero
            let offset = -(currentTime + Double.random(in: 1.0...100000.0))

            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: currentTime,
                offset: offset,
                duration: duration
            )

            #expect(result == 0, "Expected 0 when offset pulls below zero, got \(result)")
        }
    }

    @Test("Seek target clamps to duration when offset is very positive")
    func seekTargetClampsToDuration() {
        for _ in 0..<100 {
            let duration = Double.random(in: 1.0...10000.0)
            let currentTime = Double.random(in: 0...duration)
            // Offset guaranteed to exceed duration
            let offset = (duration - currentTime) + Double.random(in: 1.0...100000.0)

            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: currentTime,
                offset: offset,
                duration: duration
            )

            #expect(result == duration, "Expected duration \(duration) when offset exceeds bounds, got \(result)")
        }
    }

    @Test("Seek target equals currentTime + offset when within bounds")
    func seekTargetExactWhenInBounds() {
        for _ in 0..<100 {
            let duration = Double.random(in: 10.0...10000.0)
            let currentTime = Double.random(in: 1.0...(duration - 1.0))
            // Ensure offset keeps result within [0, duration]
            let maxPositiveOffset = duration - currentTime - 0.001
            let maxNegativeOffset = -(currentTime - 0.001)
            let offset = Double.random(in: maxNegativeOffset...maxPositiveOffset)

            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: currentTime,
                offset: offset,
                duration: duration
            )

            let expected = currentTime + offset
            #expect(
                abs(result - expected) < 1e-10,
                "Expected \(expected), got \(result) (currentTime=\(currentTime), offset=\(offset), duration=\(duration))"
            )
        }
    }

    @Test("Seek target handles very small duration")
    func seekTargetSmallDuration() {
        let duration = 0.001
        let currentTime = 0.0005
        let offsets: [Double] = [-100, -1, -0.001, 0, 0.001, 1, 100]

        for offset in offsets {
            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: currentTime,
                offset: offset,
                duration: duration
            )
            #expect(result >= 0)
            #expect(result <= duration)
        }
    }

    @Test("Seek target with zero offset returns currentTime")
    func seekTargetZeroOffset() {
        for _ in 0..<100 {
            let duration = Double.random(in: 0.001...36000.0)
            let currentTime = Double.random(in: 0...duration)

            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: currentTime,
                offset: 0,
                duration: duration
            )

            #expect(
                abs(result - currentTime) < 1e-10,
                "With zero offset, result should equal currentTime"
            )
        }
    }

    @Test("Seek target at zero boundary with negative offset stays at 0")
    func seekTargetAtZeroBoundary() {
        for _ in 0..<100 {
            let duration = Double.random(in: 1.0...10000.0)
            let offset = -Double.random(in: 0.001...100000.0)

            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: 0,
                offset: offset,
                duration: duration
            )

            #expect(result == 0)
        }
    }

    @Test("Seek target at duration boundary with positive offset stays at duration")
    func seekTargetAtDurationBoundary() {
        for _ in 0..<100 {
            let duration = Double.random(in: 1.0...10000.0)
            let offset = Double.random(in: 0.001...100000.0)

            let result = PlayerGestureLayer.computeSeekTarget(
                currentTime: duration,
                offset: offset,
                duration: duration
            )

            #expect(result == duration)
        }
    }
}

// MARK: - TVBox source and direct-play compatibility tests

@Suite("TVBox source compatibility")
struct TVBoxSourceCompatibilityTests {
    private let service = SourceService.shared

    @Test("JSON CMS detail exposes multiple direct-play sources and episodes")
    func jsonDetailBuildsPlayableEpisodeList() throws {
        let response = #"""
        {
          "list": [{
            "vod_id": 42,
            "vod_name": "Sample title",
            "vod_play_from": "HLS$$$Backup",
            "vod_play_url": "Episode 1$https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8#Episode 2$https://media.example/ep2.m3u8?token=a%2Fb$$$Episode 1$https://backup.example/master.m3u8"
          }]
        }
        """#

        let detail = try #require(service.parseDetail(response, sourceKey: "json-source", type: 1))
        #expect(detail.playFlags == ["HLS", "Backup"])
        #expect(detail.currentEpisode?.name == "Episode 1")
        #expect(detail.currentEpisode?.url == "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")
        #expect(detail.playUrlMap["HLS"]?.count == 2)
        #expect(detail.playUrlMap["Backup"]?.first?.url == "https://backup.example/master.m3u8")
        #expect(detail.sourceKey == "json-source")
    }

    @Test("Remote CMS detail uses the same direct-play payload shape")
    func remoteDetailBuildsPlayableEpisodeList() throws {
        let response = #"{"list":[{"vod_id":"r-9","vod_name":"Remote","vod_play_from":"线路A","vod_play_url":"正片$https://media.example/live.m3u8"}]}"#

        let detail = try #require(service.parseDetail(response, sourceKey: "remote-source", type: 4))
        #expect(detail.id == "r-9")
        #expect(detail.currentEpisode?.url == "https://media.example/live.m3u8")
    }

    @Test("XML CMS accepts plain text fields, alphanumeric IDs, and XML entities")
    func xmlListAcceptsCommonVariations() throws {
        let response = #"""
        <rss><class><ty id="movie">Movies &amp; more</ty></class><list><video>
          <id>film-42</id><name>Plain &amp; clear</name><pic>https://img.example/poster.jpg</pic>
          <note>Now playing</note><year>2025</year>
        </video></list></rss>
        """#

        let parsed = try service.parseSort(response, sourceBean: SourceBean(key: "xml", name: "XML", api: "https://source.example", type: 0))
        #expect(parsed.sorts.first?.id == "movie")
        #expect(parsed.sorts.first?.name == "Movies & more")
        #expect(parsed.homeVideos.first?.id == "film-42")
        #expect(parsed.homeVideos.first?.name == "Plain & clear")
        #expect(parsed.homeVideos.first?.note == "Now playing")
        #expect(parsed.homeVideos.first?.sourceKey == "xml")
    }

    @Test("XML detail preserves player flag and direct episode URL")
    func xmlDetailBuildsPlayableEpisodeList() throws {
        let response = #"""
        <rss><list><video><id>9</id><name><![CDATA[XML movie]]></name><pic></pic>
          <dd flag="hls"><![CDATA[Episode 1$https://media.example/episode.m3u8]]></dd>
        </video></list></rss>
        """#

        let detail = try #require(service.parseDetail(response, sourceKey: "xml", type: 0))
        #expect(detail.playFlags == ["hls"])
        #expect(detail.currentEpisode?.url == "https://media.example/episode.m3u8")
    }

    @Test("JAR Spider remains explicitly marked unsupported on Swift")
    func jarSpiderIsNotMisreportedAsSupported() {
        let spider = SourceBean(key: "spider", name: "Spider", api: "https://source.example", type: 3)
        #expect(!spider.isSupportedInSwift)
        #expect(spider.typeDescription == "JAR")
    }

    @Test("Type 4 direct-play responses accept only direct HTTP(S) URLs")
    func type4PlaybackResponseValidation() throws {
        let accepted: [(String, String)] = [
            (#"{"parse":0,"jx":0,"url":"https://media.example/video.m3u8"}"#, "https://media.example/video.m3u8"),
            (#"{"parse":"0","jx":"0","url":"https://media.example/video.mp4"}"#, "https://media.example/video.mp4"),
            (#"{"parse":false,"jx":false,"data":{"url":"https://media.example/nested.m3u8"}}"#, "https://media.example/nested.m3u8")
        ]

        for (response, expectedURL) in accepted {
            let resolved = try service.resolvePlaybackResponse(response)
            #expect(resolved.url == expectedURL)
        }

        let rejected = [
            #"{"parse":1,"jx":0,"url":"https://media.example/video.m3u8"}"#,
            #"{"parse":"1","jx":0,"url":"https://media.example/video.m3u8"}"#,
            #"{"parse":true,"jx":0,"url":"https://media.example/video.m3u8"}"#,
            #"{"parse":0,"jx":1,"url":"https://media.example/video.m3u8"}"#,
            #"{"parse":0,"jx":"1","url":"https://media.example/video.m3u8"}"#,
            #"{"parse":0,"jx":true,"url":"https://media.example/video.m3u8"}"#,
            #"{"parse":0,"jx":0,"header":{"User-Agent":"TVBox"},"url":"https://media.example/video.m3u8"}"#,
            "<html><body>not playerContent</body></html>",
            #"{"parse":0,"jx":0,"url":"file:///tmp/video.m3u8"}"#,
            #"{"parse":0,"jx":0,"url":"javascript:alert(1)"}"#
        ]

        for response in rejected {
            #expect(throws: SourceError.self) {
                try service.resolvePlaybackResponse(response)
            }
        }
    }

    @Test("buildURL replaces duplicate play and flag parameters while preserving token and encoding id")
    func buildURLMergesPlaybackQueryItems() throws {
        let built = try service.buildURL(
            base: "https://api.example/player?play=old&flag=old&token=keep%2Fme",
            queryItems: [
                URLQueryItem(name: "play", value: "movie/id?part=1&x+y#frag"),
                URLQueryItem(name: "flag", value: "线路 A")
            ]
        )

        let components = try #require(URLComponents(string: built))
        let items = try #require(components.queryItems)
        #expect(items.filter { $0.name == "play" }.count == 1)
        #expect(items.filter { $0.name == "flag" }.count == 1)
        #expect(items.first(where: { $0.name == "play" })?.value == "movie/id?part=1&x+y#frag")
        #expect(items.first(where: { $0.name == "flag" })?.value == "线路 A")
        #expect(items.first(where: { $0.name == "token" })?.value == "keep/me")
    }

    @Test("VodInfo preserves three source lines, duplicate names, and dollar signs in URLs")
    func vodInfoPreservesSourceLineAndEpisodeData() throws {
        let video = Movie.Video(id: "vod-1")
        let info = VodInfo.from(
            video: video,
            playFrom: "A$$$$$$A",
            playUrl: "首集$https://media.example/$token.m3u8?x=$v#空URL$"
                + "$$$空集名$https://media.example/second.m3u8"
                + "$$$重复$https://media.example/third.m3u8"
        )

        #expect(info.playFlags == ["A", "线路2", "A (2)"])
        #expect(info.playUrlMap["A"]?.count == 1)
        #expect(info.playUrlMap["A"]?.first?.url == "https://media.example/$token.m3u8?x=$v")
        #expect(info.playUrlMap["线路2"]?.first?.name == "空集名")
        #expect(info.playUrlMap["A (2)"]?.first?.url == "https://media.example/third.m3u8")
        #expect(info.playUrlMap.values.flatMap { $0 }.contains { $0.name == "空URL" } == false)
    }

    @Test("[PlaybackSmoke] Big Buck Bunny HLS reaches a three-second AVPlayer timeline")
    @MainActor
    func playbackSmokeBigBuckBunnyHLS() async throws {
        let url = try #require(URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"))
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        defer {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }

        let startedAt = Date()
        player.play()
        while Date().timeIntervalSince(startedAt) < 60 {
            let seconds = item.currentTime().seconds
            if seconds.isFinite && seconds >= 3 { break }
            if item.status == .failed { break }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        let timelineSeconds = item.currentTime().seconds
        print("[PlaybackSmoke] status=\(String(describing: item.status)) elapsed=\(String(format: "%.1f", elapsed))s timeline=\(String(format: "%.3f", timelineSeconds))s")
        #expect(item.status != .failed, "[PlaybackSmoke] AVPlayerItem failed: \(String(describing: item.error))")
        #expect(elapsed >= 3, "[PlaybackSmoke] playback did not run for the required evidence interval")
        #expect(timelineSeconds.isFinite && timelineSeconds >= 3, "[PlaybackSmoke] timeline did not reach 3 seconds")
    }
}
