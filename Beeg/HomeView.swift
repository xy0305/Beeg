import SwiftUI

struct HomeView: View {
    @StateObject private var model = HomeModel()
    @ObservedObject private var session = BeegSession.shared
    @State private var showSearch = false
    @State private var showAccount = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                avatarRail
                studioRail
                topicRail
                feed
            }
            .padding(.bottom, 28)
        }
        .background(BeegTheme.background.ignoresSafeArea())
        .task { await model.loadIfNeeded() }
        .refreshable { await model.reload() }
        .sheet(isPresented: $showSearch) {
            SearchView()
        }
        .sheet(isPresented: $showAccount) {
            AccountView()
        }
        .navigationDestination(for: BeegVideo.self) { video in
            VideoDetailView(video: video)
        }
        .navigationDestination(for: BeegTag.self) { tag in
            TagFeedView(tag: tag)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            BeegWordmark()
            Spacer()
            iconButton("sparkles", label: "AI") { showSearch = true }
            iconButton("video", label: "视频") {}
            iconButton("magnifyingglass", label: "搜索") { showSearch = true }
            iconButton("person", label: "账号") { showAccount = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var avatarRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(model.people) { tag in
                    NavigationLink(value: tag) {
                        VStack(spacing: 6) {
                            CircleAvatar(url: tag.avatar, size: 68)
                            Text(tag.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(BeegTheme.muted)
                                .lineLimit(1)
                                .frame(width: 74)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var studioRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(model.studios) { tag in
                    NavigationLink(value: tag) {
                        HStack(spacing: 8) {
                            CircleAvatar(url: tag.avatar, size: 28)
                            Text(tag.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 12)
                        .padding(.vertical, 4)
                        .background(BeegTheme.chip, in: Capsule())
                        .overlay(Capsule().stroke(BeegTheme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var topicRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(model.topics) { tag in
                    NavigationLink(value: tag) {
                        Text(tag.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(BeegTheme.chip, in: Capsule())
                            .overlay(Capsule().stroke(BeegTheme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var feed: some View {
        LazyVStack(spacing: 22) {
            if let message = model.error, model.videos.isEmpty {
                VStack(spacing: 12) {
                    Text(message).foregroundStyle(BeegTheme.muted)
                    Button("重试") { Task { await model.reload() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            ForEach(model.videos) { video in
                VideoCard(video: video)
                    .onAppear { Task { await model.loadMoreIfNeeded(video) } }
            }
            if model.isLoading {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding()
            }
        }
    }

    private func iconButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .regular))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }
}

@MainActor
final class HomeModel: ObservableObject {
    @Published var people: [BeegTag] = []
    @Published var studios: [BeegTag] = []
    @Published var topics: [BeegTag] = []
    @Published var videos: [BeegVideo] = []
    @Published var isLoading = false
    @Published var error: String?

    private let client = BeegClient()
    private var offset = 0
    private var hasMore = true
    private var started = false

    func loadIfNeeded() async {
        guard !started else { return }
        started = true
        await reload()
    }

    func reload() async {
        let previous = (videos, people, studios, topics, offset, hasMore)
        offset = 0
        hasMore = true
        error = nil
        async let peopleRequest = client.recommends(type: "person")
        async let studiosRequest = client.recommends(type: "brand")
        async let topicsRequest = client.recommends(type: "other")
        let refreshedPeople = (try? await peopleRequest) ?? previous.1
        let refreshedStudios = (try? await studiosRequest) ?? previous.2
        let refreshedTopics = (try? await topicsRequest) ?? previous.3
        do {
            let page = try await client.home(offset: 0)
            videos = page
            people = refreshedPeople
            studios = refreshedStudios
            topics = refreshedTopics
            offset = page.count
            hasMore = page.count >= BeegCatalog.minimumPageSize
            error = nil
        } catch {
            videos = previous.0
            people = previous.1
            studios = previous.2
            topics = previous.3
            offset = previous.4
            hasMore = previous.5
            guard !BeegCatalog.isCancellation(error) else { return }
            self.error = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(_ video: BeegVideo) async {
        guard video.id == videos.suffix(3).first?.id else { return }
        await loadMore()
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await client.home(offset: offset)
            let existing = Set(videos.map(\.id))
            videos.append(contentsOf: page.filter { !existing.contains($0.id) })
            offset += page.count
            hasMore = page.count >= BeegCatalog.minimumPageSize
            error = nil
        } catch {
            guard !BeegCatalog.isCancellation(error) else { return }
            self.error = error.localizedDescription
            hasMore = false
        }
    }
}
