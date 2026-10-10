import SwiftUI

enum BeegTheme {
    static let background = Color(red: 0.008, green: 0.016, blue: 0.031)
    static let card = Color(red: 0.055, green: 0.063, blue: 0.078)
    static let chip = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.14)
    static let muted = Color.white.opacity(0.62)
    static let faint = Color.white.opacity(0.42)
}

struct BeegWordmark: View {
    var body: some View {
        Text("beeg")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .tracking(-1.4)
            .foregroundStyle(.white)
            .accessibilityLabel("beeg")
    }
}

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        Color.white.opacity(0.06)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: contentMode)
                        }
                    }
                }
            }
            .clipped()
    }
}

struct CircleAvatar: View {
    let url: URL?
    var size: CGFloat = 68

    var body: some View {
        RemoteImage(url: url)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.5))
    }
}
