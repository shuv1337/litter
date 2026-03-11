import SwiftUI
import WebKit

struct OAuthWebView: UIViewRepresentable {
    let url: URL
    var onCallbackIntercepted: ((URL) -> Void)?
    var onDismiss: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCallbackIntercepted: onCallbackIntercepted, onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onCallbackIntercepted: ((URL) -> Void)?
        let onDismiss: (() -> Void)?
        init(onCallbackIntercepted: ((URL) -> Void)?, onDismiss: (() -> Void)?) {
            self.onCallbackIntercepted = onCallbackIntercepted
            self.onDismiss = onDismiss
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               (url.host == "localhost" || url.host == "127.0.0.1"),
               url.path.contains("/auth/callback") {
                decisionHandler(.cancel)
                if let handler = onCallbackIntercepted {
                    handler(url)
                } else {
                    Task { _ = try? await URLSession.shared.data(from: url) }
                }
                return
            }
            decisionHandler(.allow)
        }
    }
}
