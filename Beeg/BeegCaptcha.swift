import Foundation
import WebKit

enum BeegCaptcha {
    private static let siteKey = "6LdKZBgqAAAAABHQx-Y7iT6mpedEwu4XhvFFCdMN"

    static func token(action: String) async throws -> String {
        guard ["signin", "signup"].contains(action) else { throw BeegAPIError.rejected("无效验证操作") }
        return try await CaptchaRunner(action: action).run()
    }

    private final class CaptchaRunner: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let action: String
        private var continuation: CheckedContinuation<String, Error>?
        private var webView: WKWebView?

        init(action: String) { self.action = action }

        func run() async throws -> String {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                Task { @MainActor in
                    let content = WKUserContentController()
                    content.add(self, name: "captcha")
                    let configuration = WKWebViewConfiguration()
                    configuration.userContentController = content
                    let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
                    web.navigationDelegate = self
                    self.webView = web
                    let html = """
                    <!doctype html><html><head>
                    <script src="https://www.recaptcha.net/recaptcha/enterprise.js?render=\(siteKey)"></script>
                    </head><body><script>
                    function send(value){webkit.messageHandlers.captcha.postMessage(value)}
                    grecaptcha.enterprise.ready(function(){
                      grecaptcha.enterprise.execute("\(siteKey)",{action:"\(action)"})
                        .then(function(token){send(token)})
                        .catch(function(){send("")})
                    })
                    </script></body></html>
                    """
                    web.loadHTMLString(html, baseURL: URL(string: "https://beeg.com/"))
                }
                Task {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    self.finish(.failure(BeegAPIError.rejected("登录验证超时")))
                }
            }
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            let token = (message.body as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard token.count >= 20, token.count <= 4_096, token.allSatisfy({ !$0.isWhitespace }) else {
                finish(.failure(BeegAPIError.rejected("登录验证失败")))
                return
            }
            finish(.success(token))
        }

        private func finish(_ result: Result<String, Error>) {
            let pending = continuation
            continuation = nil
            pending?.resume(with: result)
            Task { @MainActor in self.webView = nil }
        }
    }
}
