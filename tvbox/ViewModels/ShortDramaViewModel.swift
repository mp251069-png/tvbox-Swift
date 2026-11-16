import Foundation
import SwiftUI

@MainActor
final class ShortDramaHomeViewModel: ObservableObject {
    @Published var videos: [ShortDramaVideo] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = false
    @Published var errorMessage: String?

    private let service = ShortDramaService.shared
    private var page = 1
    private let pageSize = 24

    func loadFirstPage() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        page = 1
        defer { isLoading = false }
        do {
            let result = try await fetch(page: 1)
            videos = result.items
            page = result.pagination?.page ?? 1
            hasMore = result.pagination?.pages.map { page < $0 } ?? (result.items.count >= pageSize)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await loadFirstPage()
    }

    func search() async {
        await loadFirstPage()
    }

    func clearSearch() async {
        searchText = ""
        await loadFirstPage()
    }

    func loadMore() async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await fetch(page: page + 1)
            let newItems = result.items.filter { next in !videos.contains(where: { $0.id == next.id }) }
            videos.append(contentsOf: newItems)
            page = result.pagination?.page ?? page + 1
            let serverHasMore = result.pagination?.pages.map { page < $0 } ?? (result.items.count >= pageSize)
            hasMore = !newItems.isEmpty && serverHasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetch(page: Int) async throws -> ShortDramaPage {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return try await service.fetchFeed(page: page, size: pageSize)
        }
        return try await service.search(query, page: page, size: pageSize)
    }
}

@MainActor
final class ShortDramaDetailViewModel: ObservableObject {
    @Published private(set) var video: ShortDramaVideo
    @Published var isLoading = false
    @Published var isResolvingPlayback = false
    @Published var errorMessage: String?
    @Published private(set) var playbackURLs: [String] = []
    @Published private(set) var selectedPlaybackIndex = 0
    @Published var isShowingPlayer = false
    @Published private(set) var selectedEpisode = 1

    private let service = ShortDramaService.shared
    private var didLoadDetail = false

    init(video: ShortDramaVideo) {
        self.video = video
        selectedEpisode = video.episodes.first?.epNum ?? 1
    }

    var episodes: [ShortDramaEpisode] {
        if !video.episodes.isEmpty { return video.episodes }
        let count = max(video.totalEpisodes, video.episodeCount)
        guard count > 0 else { return [] }
        return (1...min(count, 500)).map {
            ShortDramaEpisode(epNum: $0, title: "第\($0)集", duration: 0, status: 0)
        }
    }

    var hasNextEpisode: Bool {
        episodes.contains { $0.epNum > selectedEpisode }
    }

    var playbackURL: String? {
        guard playbackURLs.indices.contains(selectedPlaybackIndex) else { return nil }
        return playbackURLs[selectedPlaybackIndex]
    }

    var hasAlternateStream: Bool { playbackURLs.count > 1 }

    func selectNextPlaybackOption() {
        guard playbackURLs.count > 1 else { return }
        selectedPlaybackIndex = (selectedPlaybackIndex + 1) % playbackURLs.count
    }

    func loadDetail() async {
        guard !didLoadDetail, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            video = try await service.detail(id: video.id)
            selectedEpisode = episodes.first?.epNum ?? 1
            didLoadDetail = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playEpisode(_ episode: Int) async {
        guard !isResolvingPlayback else { return }
        selectedEpisode = episode
        isResolvingPlayback = true
        errorMessage = nil
        defer { isResolvingPlayback = false }
        do {
            let urls = try await service.playbackURLs(videoID: video.id, episode: episode)
            playbackURLs = urls
            selectedPlaybackIndex = 0
            isShowingPlayer = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playNextEpisode() async {
        guard let next = episodes.first(where: { $0.epNum > selectedEpisode }) else { return }
        await playEpisode(next.epNum)
    }
}
