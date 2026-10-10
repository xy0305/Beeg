import SwiftUI
import AVFoundation
import KSPlayer

struct BeegPlayer: View {
    let qualities: [BeegQuality]
    @State private var selectedID: String
    @State private var fullscreen = false
    @State private var showQualities = false
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    init(qualities: [BeegQuality]) {
        self.qualities = qualities
        _selectedID = State(initialValue: qualities.first?.id ?? "")
    }

    var body: some View {
        stage(fullscreen: false)
            .fullScreenCover(isPresented: $fullscreen) {
                LandscapeHost {
                    stage(fullscreen: true)
                }
                .ignoresSafeArea()
            }
            .onAppear { activateAudio() }
            .onDisappear {
                coordinator.playerLayer?.pause()
                OrientationLock.set(.portrait)
            }
            .confirmationDialog("画质", isPresented: $showQualities, titleVisibility: .visible) {
                ForEach(qualities) { quality in
                    Button(quality.id == selectedID ? "\(quality.label) ✓" : quality.label) {
                        switchQuality(quality)
                    }
                }
                Button("取消", role: .cancel) {}
            }
    }

    private func stage(fullscreen: Bool) -> some View {
        ZStack {
            Color.black
            if let quality = selected {
                KSVideoPlayer(coordinator: coordinator, url: quality.url, options: playbackOptions)
            }
            controls(fullscreen: fullscreen)
        }
        .background(Color.black)
    }

    private func controls(fullscreen: Bool) -> some View {
        VStack {
            HStack(spacing: 4) {
                if fullscreen {
                    controlButton("chevron.left", label: "退出横屏") {
                        self.fullscreen = false
                    }
                }
                Spacer()
                Button {
                    showQualities = true
                } label: {
                    Text(selected?.label ?? "画质")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                .accessibilityLabel("切换画质")
                controlButton(
                    fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    label: fullscreen ? "退出横屏" : "横屏播放"
                ) {
                    self.fullscreen.toggle()
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, fullscreen ? 16 : 6)
            Spacer()
        }
        .foregroundStyle(.white)
    }

    private func controlButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }

    private var selected: BeegQuality? {
        qualities.first { $0.id == selectedID } ?? qualities.first
    }

    private var playbackOptions: KSOptions {
        let options = KSOptions()
        options.appendHeader([
            "Referer": "https://beeg.com/",
            "Origin": "https://beeg.com"
        ])
        options.userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"
        options.referer = "https://beeg.com/"
        KSOptions.isAutoPlay = true
        return options
    }

    private func switchQuality(_ quality: BeegQuality) {
        let time = coordinator.playerLayer?.player.currentPlaybackTime ?? 0
        selectedID = quality.id
        coordinator.playerLayer?.set(url: quality.url, options: playbackOptions)
        if time > 1 {
            coordinator.playerLayer?.seek(time: time, autoPlay: true, completion: { _ in })
        }
    }

    private func activateAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

private struct LandscapeHost<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> LandscapeController<Content> {
        LandscapeController(rootView: content)
    }

    func updateUIViewController(_ controller: LandscapeController<Content>, context: Context) {
        controller.rootView = content
    }
}

private final class LandscapeController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OrientationLock.set(.landscapeRight)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        OrientationLock.set(.portrait)
    }
}

enum OrientationLock {
    static func set(_ mask: UIInterfaceOrientationMask) {
        let resolved: UIInterfaceOrientationMask = UIDevice.current.userInterfaceIdiom == .pad && mask == .portrait ? .all : mask
        KSOptions.supportedInterfaceOrientations = resolved
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        scene?.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: resolved)) { _ in }
        scene?.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}
