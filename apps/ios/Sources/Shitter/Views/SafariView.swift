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

struct OAuthLoginSheetView: View {
    let connection: ServerConnection
    var onCancel: (() -> Void)? = nil

    var body: some View {
        if let url = connection.oauthURL {
            NavigationStack {
                OAuthWebView(url: url, onCallbackIntercepted: { callbackURL in
                    connection.forwardOAuthCallback(callbackURL)
                }) {
                    Task { await connection.cancelLogin() }
                }
                .ignoresSafeArea()
                .navigationTitle("Login with ChatGPT")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            Task { await connection.cancelLogin() }
                            onCancel?()
                        }
                        .foregroundColor(ShitterTheme.danger)
                    }
                }
            }
        }
    }
}

private struct OAuthLoginPresenter: ViewModifier {
    let connection: ServerConnection?

    private var oauthConnection: ServerConnection? {
        guard let connection, connection.oauthURL != nil else { return nil }
        return connection
    }

    func body(content: Content) -> some View {
        content
            .task(id: connection?.id) {
                await connection?.checkAuth()
            }
            .sheet(item: Binding(
                get: { oauthConnection },
                set: { nextValue in
                    guard nextValue == nil, let connection else { return }
                    Task { await connection.cancelLogin() }
                }
            )) { oauthConnection in
                OAuthLoginSheetView(connection: oauthConnection)
            }
    }
}

extension View {
    func oauthLoginPresenter(connection: ServerConnection?) -> some View {
        modifier(OAuthLoginPresenter(connection: connection))
    }
}
