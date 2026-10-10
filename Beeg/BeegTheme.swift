import SwiftUI
import WebKit

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
                    if url.pathExtension.lowercased() == "svg" {
                        SVGImage(url: url)
                    } else {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: contentMode)
                            }
                        }
                    }
                }
            }
            .clipped()
    }
}

private struct SVGImage: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.isUserInteractionEnabled = false
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.loaded != url else { return }
        context.coordinator.loaded = url
        let page = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;background:transparent;width:100%;height:100%}img{width:100%;height:100%;object-fit:cover}</style>
        </head><body><img src="\(url.absoluteString)"></body></html>
        """
        web.loadHTMLString(page, baseURL: URL(string: "https://beeg.com/"))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loaded: URL?
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
