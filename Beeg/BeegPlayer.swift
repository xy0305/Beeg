import SwiftUI
import AVFoundation
import KSPlayer

struct BeegPlayer: View {
    let url: URL
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var started = false

    var body: some View {
        ZStack {
            Color.black
            KSVideoPlayer(coordinator: coordinator, url: url, options: playbackOptions)
                .onStateChanged { _, state in
                    if state == .bufferFinished || state == .readyToPlay {
                        started = true
                    }
                }
            if !started {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        .onDisappear {
            coordinator.playerLayer?.pause()
        }
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
}
