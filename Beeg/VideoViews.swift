import SwiftUI

struct VideoCard: View {
    let video: BeegVideo
    @State private var frame = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                TabView(selection: $frame) {
                    ForEach(frameIndexes, id: \.self) { index in
                        NavigationLink(value: video) {
                            RemoteImage(url: BeegClient.frameURL(fileID: video.id, second: video.thumbs.isEmpty ? 0 : video.thumbs[index], width: 1280))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

                HStack {
                    HStack(spacing: 5) {
                        ForEach(frameIndexes, id: \.self) { index in
                            Circle()
                                .fill(index == frame ? Color.white : Color.white.opacity(0.38))
                                .frame(width: index == frame ? 7 : 5, height: index == frame ? 7 : 5)
                        }
                    }
                    Spacer()
                    Text(BeegCatalog.duration(video.duration))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.42), in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 10)

            HStack(alignment: .center, spacing: 10) {
                if video.ownerSlug.isEmpty {
                    CircleAvatar(url: video.ownerAvatar, size: 38)
                } else {
                    NavigationLink(value: ownerTag) {
                        CircleAvatar(url: video.ownerAvatar, size: 38)
                    }
                    .buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(video.ownerName.isEmpty ? "beeg" : video.ownerName)
                        .font(.system(size: 16, weight: .semibold))
                    Text(video.title)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(BeegCatalog.compactCount(video.views))
                        Text(BeegCatalog.relativeDate(video.created))
                        Image(systemName: "heart")
                            .font(.system(size: 11))
                        Text(BeegCatalog.compactCount(video.likes))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(BeegTheme.faint)
                }
                Spacer(minLength: 0)
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(BeegTheme.faint)
            }
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
        }
    }

    private var frameIndexes: [Int] {
        let count = min(max(video.thumbs.count, 1), 8)
        return Array(0..<count)
    }

    private var ownerTag: BeegTag {
        BeegTag(id: stableOwnerID, name: video.ownerName, slug: video.ownerSlug, kind: "owner", avatar: video.ownerAvatar)
    }

    private var stableOwnerID: Int {
        video.ownerSlug.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
    }
}

struct VideoDetailView: View {
    let video: BeegVideo
    @State private var playbackURL: URL?
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                player
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 10)
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.system(size: 20, weight: .semibold))
                    HStack(spacing: 8) {
                        Text(BeegCatalog.compactCount(video.views))
                        Text("·")
                        Text("\(BeegCatalog.compactCount(video.likes)) Likes")
                    }
                    .foregroundStyle(BeegTheme.muted)
                    HStack(spacing: 12) {
                        CircleAvatar(url: video.ownerAvatar, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(video.ownerName.isEmpty ? "beeg" : video.ownerName)
                                .font(.system(size: 18, weight: .bold))
                            Text(BeegCatalog.duration(video.duration))
                                .foregroundStyle(BeegTheme.muted)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .foregroundStyle(.white)
            }
            .padding(.bottom, 24)
        }
        .background(BeegTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BeegTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await load() }
    }

    @ViewBuilder
    private var player: some View {
        if let playbackURL {
            BeegPlayer(url: playbackURL)
        } else if loading {
            ZStack {
                RemoteImage(url: BeegClient.frameURL(fileID: video.id, second: video.thumbs.first ?? 0, width: 1280))
                ProgressView().tint(.white)
            }
        } else {
            ContentUnavailableView("无法播放", systemImage: "play.slash", description: Text(error ?? "请稍后重试"))
                .foregroundStyle(.white)
        }
    }

    private func load() async {
        do {
            playbackURL = try await BeegClient().playbackURL(fileID: video.id)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct TagFeedView: View {
    let tag: BeegTag
    @State private var videos: [BeegVideo] = []
    @State private var offset = 0
    @State private var hasMore = true
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                if let error, videos.isEmpty {
                    VStack(spacing: 12) {
                        Text(error).foregroundStyle(BeegTheme.muted)
                        Button("重试") {
                            hasMore = true
                            Task { await load() }
                        }
                    }
                    .padding(.top, 40)
                }
                ForEach(videos) { video in
                    VideoCard(video: video)
                        .onAppear {
                            guard video.id == videos.suffix(3).first?.id else { return }
                            Task { await load() }
                        }
                }
                if loading { ProgressView().tint(.white).padding() }
            }
            .padding(.vertical, 8)
        }
        .background(BeegTheme.background.ignoresSafeArea())
        .navigationTitle(tag.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BeegTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        guard hasMore, !loading, !tag.slug.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await BeegClient().videos(slug: tag.slug, offset: offset)
            let existing = Set(videos.map(\.id))
            videos.append(contentsOf: page.filter { !existing.contains($0.id) })
            offset += page.count
            hasMore = page.count >= BeegCatalog.minimumPageSize
            error = nil
        } catch {
            self.error = error.localizedDescription
            hasMore = false
        }
    }
}

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var tags: [BeegTag] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if tags.isEmpty, !loading {
                    ContentUnavailableView(error ?? "搜索演员、片商或标签", systemImage: "magnifyingglass")
                } else {
                    List(tags) { tag in
                        NavigationLink(value: tag) {
                            HStack(spacing: 12) {
                                CircleAvatar(url: tag.avatar, size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tag.displayName)
                                    Text(tag.kind).font(.caption).foregroundStyle(BeegTheme.muted)
                                }
                            }
                        }
                        .listRowBackground(BeegTheme.background)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(BeegTheme.background)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BeegTag.self) { TagFeedView(tag: $0) }
            .searchable(text: $query, prompt: "搜索")
            .onSubmit(of: .search) { Task { await search() } }
            .overlay { if loading { ProgressView().tint(.white) } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .toolbarBackground(BeegTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            tags = try await BeegClient().searchTags(query: trimmed)
            error = tags.isEmpty ? "没有找到结果" : nil
        } catch {
            tags = []
            self.error = error.localizedDescription
        }
    }
}
