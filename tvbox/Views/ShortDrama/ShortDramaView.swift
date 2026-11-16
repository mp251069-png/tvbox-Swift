import SwiftUI
#if os(iOS)
import UIKit
private typealias ShortDramaPlatformImage = UIImage
#elseif os(macOS)
import AppKit
private typealias ShortDramaPlatformImage = NSImage
#endif

/// HGhubX 短剧原生入口：不嵌入 Tauri WebView，也不提供下载功能。
struct ShortDramaView: View {
    @StateObject private var viewModel = ShortDramaHomeViewModel()
    @State private var isShowingServerSettings = false

    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 210), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchBar
                    contentNotice
                    contentBody
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(AppTheme.primaryGradient)
            .navigationTitle("短剧")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingServerSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("短剧服务设置")
                }
            }
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadFirstPage() }
            .sheet(isPresented: $isShowingServerSettings) {
                ShortDramaServerSettingsView {
                    Task { await viewModel.refresh() }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
            TextField("搜索短剧", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.search() } }
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
            if !viewModel.searchText.isEmpty {
                Button {
                    Task { await viewModel.clearSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
            Button("搜索") { Task { await viewModel.search() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var contentNotice: some View {
        Label {
            Text("第三方内容由上游站点提供，部分简介可能涉及成人或敏感题材；本入口不提供下载功能，请自行判断并遵守当地法律。")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.isLoading && viewModel.videos.isEmpty {
            VStack(spacing: 12) {
                ProgressView().tint(.orange)
                Text("正在加载短剧")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
            ContentUnavailableView {
                Label("短剧暂时无法加载", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("重试") { Task { await viewModel.refresh() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .foregroundStyle(.white)
            .padding(.top, 36)
        } else if viewModel.videos.isEmpty {
            ContentUnavailableView("没有找到短剧", systemImage: "film")
                .foregroundStyle(.white)
                .padding(.top, 36)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(viewModel.videos) { video in
                    NavigationLink {
                        ShortDramaDetailView(video: video)
                    } label: {
                        ShortDramaCard(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
            if viewModel.hasMore {
                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoadingMore { ProgressView().tint(.white) }
                        Text(viewModel.isLoadingMore ? "正在加载" : "加载更多")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingMore)
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

private struct ShortDramaCard: View {
    let video: ShortDramaVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                ShortDramaCoverView(url: video.cover)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 13))
                HStack(spacing: 5) {
                    Image(systemName: video.isFinished ? "checkmark.circle.fill" : "play.circle.fill")
                    Text(video.isFinished ? "已完结" : "更新至\(video.episodeCount)集")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            Text(video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                HStack(spacing: 7) {
                    if video.score > 0 {
                        Label(String(format: "%.1f", video.score), systemImage: "star.fill")
                            .foregroundStyle(.orange)
                    }
                    if let tag = video.tags.first {
                        Text(tag).foregroundStyle(.white.opacity(0.52)).lineLimit(1)
                    }
                }
                .font(.system(size: 11))
        }
        .contentShape(Rectangle())
    }
}

private struct ShortDramaCoverView: View {
    let url: String
    @State private var image: ShortDramaPlatformImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(0.07))
            if let image {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                #endif
            } else {
                Image(systemName: "film.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.22))
            }
        }
        .clipped()
        .task(id: url) {
            image = nil
            guard !url.isEmpty, let data = try? await ShortDramaService.shared.coverData(from: url) else { return }
            #if os(iOS)
            image = UIImage(data: data)
            #elseif os(macOS)
            image = NSImage(data: data)
            #endif
        }
    }
}

private struct ShortDramaServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var origin: String
    @State private var errorMessage: String?
    private let onSaved: () -> Void

    init(onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
        _origin = State(initialValue: ShortDramaService.shared.currentOrigin)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("HGhubX 服务") {
                    TextField("HTTPS 服务地址", text: $origin)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    Text("只填写 HTTPS 主机地址，例如 https://example.com；默认使用 HGhubX 当前公开服务。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("恢复默认服务") {
                        ShortDramaService.shared.resetOrigin()
                        origin = ShortDramaService.defaultOrigin
                        errorMessage = nil
                    }
                }
                Section {
                    Text("本页仅接入访客浏览、搜索与播放。账号互动、批量抓取和下载功能未移植。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("查看 HGhubX 项目与许可", destination: URL(string: "https://github.com/zxsos/HGhubX")!)
                        .font(.footnote)
                }
            }
            .navigationTitle("短剧服务设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .alert("无法保存服务地址", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private func save() {
        do {
            try ShortDramaService.shared.saveOrigin(origin)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShortDramaDetailView: View {
    @StateObject private var viewModel: ShortDramaDetailViewModel
    @State private var isDescriptionExpanded = false

    init(video: ShortDramaVideo) {
        _viewModel = StateObject(wrappedValue: ShortDramaDetailViewModel(video: video))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    ShortDramaCoverView(url: viewModel.video.cover)
                        .frame(width: 126)
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.video.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text(viewModel.video.isFinished ? "已完结" : "更新至\(viewModel.video.episodeCount)集")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.orange)
                        if viewModel.video.score > 0 {
                            Label(String(format: "%.1f 分", viewModel.video.score), systemImage: "star.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        if !viewModel.video.tags.isEmpty {
                            Text(viewModel.video.tags.joined(separator: " · "))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button {
                            Task { await viewModel.playEpisode(viewModel.selectedEpisode) }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isResolvingPlayback { ProgressView().tint(.white) }
                                else { Image(systemName: "play.fill") }
                                Text(viewModel.isResolvingPlayback ? "正在获取播放地址" : "立即播放")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isResolvingPlayback || viewModel.episodes.isEmpty)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.isLoading {
                    ProgressView("正在加载剧集信息")
                        .tint(.orange)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !viewModel.video.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("简介")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(viewModel.video.summary)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(isDescriptionExpanded ? nil : 5)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(isDescriptionExpanded ? "收起" : "展开简介") {
                            isDescriptionExpanded.toggle()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("选集")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("共 \(viewModel.episodes.count) 集")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(viewModel.episodes) { episode in
                            Button {
                                Task { await viewModel.playEpisode(episode.epNum) }
                            } label: {
                                Text(episode.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundStyle(viewModel.selectedEpisode == episode.epNum ? .white : .white.opacity(0.75))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(
                                        viewModel.selectedEpisode == episode.epNum ? Color.orange.opacity(0.88) : Color.white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 9)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isResolvingPlayback)
                        }
                    }
                }

                Text("内容与播放地址来自第三方上游；本应用不下载或保存媒体文件。")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(18)
        }
        .background(AppTheme.primaryGradient)
        .navigationTitle(viewModel.video.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.loadDetail() }
        .fullScreenCover(isPresented: $viewModel.isShowingPlayer) {
            ShortDramaPlayerView(viewModel: viewModel)
        }
    }
}

private struct ShortDramaPlayerView: View {
    @ObservedObject var viewModel: ShortDramaDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.video.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("第 \(viewModel.selectedEpisode) 集")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    if viewModel.isResolvingPlayback {
                        ProgressView().tint(.orange)
                    }
                    if viewModel.hasAlternateStream {
                        Button {
                            viewModel.selectNextPlaybackOption()
                        } label: {
                            Label("换流", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        .disabled(viewModel.isResolvingPlayback)
                    }
                    if viewModel.hasNextEpisode {
                        Button("下一集") { Task { await viewModel.playNextEpisode() } }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                            .disabled(viewModel.isResolvingPlayback)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
                if let url = viewModel.playbackURL {
                    PlayerView(
                        urlString: url,
                        onPlaybackEnded: { Task { await viewModel.playNextEpisode() } },
                        canPlayNext: viewModel.hasNextEpisode,
                        onPlayNext: { Task { await viewModel.playNextEpisode() } }
                    )
                    .id(url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(.black)
                }
                Spacer(minLength: 0)
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.bottom, 18)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
