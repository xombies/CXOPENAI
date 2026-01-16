import SwiftUI
import AppKit
import WebKit

struct WebHomepageView: View {
    @StateObject private var server: LocalHomepageServer
    @State private var isLoading = true

    init() {
        let htmlURL = Bundle.main.url(forResource: "Homepage", withExtension: "html")
            ?? Bundle.module.url(forResource: "Homepage", withExtension: "html")
        let htmlData = (htmlURL.flatMap { try? Data(contentsOf: $0) }) ?? Data("<h1>Missing Homepage.html</h1>".utf8)
        let server = LocalHomepageServer(homepageHTML: htmlData)
        _server = StateObject(wrappedValue: server)
        server.start()
    }

    var body: some View {
        ZStack {
            WebView(url: server.url, isLoading: $isLoading)
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            server.start()
        }
        .onDisappear {
            server.stop()
        }
    }
}

private struct WebView: NSViewRepresentable {
    let url: URL?
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let url else { return }
        guard context.coordinator.lastLoadedURL != url else { return }
        context.coordinator.lastLoadedURL = url
        nsView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool
        var lastLoadedURL: URL?

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            DispatchQueue.main.async {
                webView.window?.makeFirstResponder(webView)
                webView.evaluateJavaScript("document.getElementById('topicInput')?.focus();")
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            return nil
        }
    }
}
