import SwiftUI
import AVFoundation
import KSPlayer

struct BeegPlayer: View {
    let qualities: [BeegQuality]
    @State private var selectedID: String
    @State private var showQualities = false
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    init(qualities: [BeegQuality]) {
        self.qualities = qualities
        _selectedID = State(initialValue: qualities.first?.id ?? "")
    }

    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                Color.black
                if let quality = selected {
                    KSVideoPlayer(coordinator: coordinator, url: quality.url, options: playbackOptions)
                }
                controls(landscape: landscape)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea(landscape ? .all : [])
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

    private func controls(landscape: Bool) -> some View {
        VStack {
            HStack {
                if landscape {
                    Button {
                        OrientationLock.set(.portrait)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                }
                Spacer()
                Button {
                    showQualities = true
                } label: {
                    Text(selected?.label ?? "画质")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                Button {
                    OrientationLock.set(landscape ? .portrait : .landscapeRight)
                } label: {
                    Image(systemName: landscape ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, landscape ? 8 : 4)
            Spacer()
        }
        .foregroundStyle(.white)
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
            coordinator.playerLayer?.seek(time: time, completion: { _ in })
        }
    }

    private func activateAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

enum OrientationLock {
    static func set(_ mask: UIInterfaceOrientationMask) {
        let resolved: UIInterfaceOrientationMask = UIDevice.current.userInterfaceIdiom == .pad && mask == .portrait ? .all : mask
        KSOptions.supportedInterfaceOrientations = resolved
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.windows.first(where: \.isKeyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: resolved)) { _ in }
    }
}
