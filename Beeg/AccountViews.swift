import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = BeegSession.shared
    @State private var email = ""
    @State private var password = ""
    @State private var signingUp = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if session.isLoggedIn {
                    loggedIn
                } else {
                    loginForm
                }
            }
            .background(BeegTheme.background)
            .navigationTitle(session.isLoggedIn ? "账号" : (signingUp ? "注册" : "登录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .toolbarBackground(BeegTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: BeegVideo.self) { VideoDetailView(video: $0) }
        }
        .preferredColorScheme(.dark)
    }

    private var loggedIn: some View {
        List {
            Section {
                Label(session.account?.email ?? "已登录", systemImage: "person.crop.circle")
            }
            Section {
                NavigationLink("关注的视频") { FollowingView() }
            }
            Section {
                Button("退出登录", role: .destructive) {
                    Task { await session.logout() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("邮箱", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(BeegTheme.chip, in: RoundedRectangle(cornerRadius: 12))
            SecureField("密码", text: $password)
                .textContentType(signingUp ? .newPassword : .password)
                .padding(14)
                .background(BeegTheme.chip, in: RoundedRectangle(cornerRadius: 12))
            if let message = session.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button(signingUp ? "注册并登录" : "登录") {
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy)
            Button(signingUp ? "已有账号，去登录" : "没有账号，注册") {
                signingUp.toggle()
                session.message = nil
            }
            .foregroundStyle(.white)
            Spacer()
        }
        .padding(20)
        .foregroundStyle(.white)
        .overlay { if busy { ProgressView().tint(.white) } }
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        let ok = signingUp
            ? await session.signup(email: email, password: password)
            : await session.login(email: email, password: password)
        if ok {
            password = ""
            dismiss()
        }
    }
}

struct FollowingView: View {
    @State private var videos: [BeegVideo] = []
    @State private var offset = 0
    @State private var hasMore = true
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                if let error, videos.isEmpty {
                    Text(error).foregroundStyle(BeegTheme.muted).padding(.top, 40)
                }
                ForEach(videos) { video in
                    VideoCard(video: video)
                        .onAppear {
                            guard video.id == videos.suffix(3).first?.id else { return }
                            Task { await load() }
                        }
                }
                if loading { ProgressView().tint(.white) }
            }
            .padding(.vertical, 8)
        }
        .background(BeegTheme.background.ignoresSafeArea())
        .navigationTitle("关注")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard hasMore, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await BeegClient().followedVideos(offset: offset)
            let existing = Set(videos.map(\.id))
            videos.append(contentsOf: page.filter { !existing.contains($0.id) })
            offset += page.count
            hasMore = page.count >= BeegCatalog.minimumPageSize
            error = videos.isEmpty ? "还没有关注的视频" : nil
        } catch {
            self.error = error.localizedDescription
            hasMore = false
        }
    }
}
