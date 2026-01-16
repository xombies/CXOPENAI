import Foundation
import Network

final class LocalHomepageServer: ObservableObject {
    @Published private(set) var url: URL?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "LocalHomepageServer")
    private let homepageHTML: Data
    private let ollamaBaseURL: URL

    init(homepageHTML: Data, ollamaBaseURL: URL = URL(string: "http://localhost:11434")!) {
        self.homepageHTML = homepageHTML
        self.ollamaBaseURL = ollamaBaseURL
    }

    func start() {
        guard listener == nil else { return }
        startListener(preferPort8000: true)
    }

    private func startListener(preferPort8000: Bool) {
        do {
#if DEBUG
            print("LocalHomepageServer: starting…")
#endif
            let listener = try NWListener(
                using: .tcp,
                on: preferPort8000 ? NWEndpoint.Port(rawValue: 8000)! : .any
            )
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                guard self.listener === listener else { return }
                switch state {
                case .ready:
                    if let port = listener.port {
                        let nextURL = URL(string: "http://localhost:\(port.rawValue)/Homepage.html")
                        DispatchQueue.main.async {
                            self.url = nextURL
                        }
#if DEBUG
                        print("LocalHomepageServer: ready at \(nextURL?.absoluteString ?? "(nil)")")
#endif
                    }
                case .failed(let error):
#if DEBUG
                    print("LocalHomepageServer: failed \(error)")
#endif
                    if preferPort8000, Self.isAddressInUse(error) {
#if DEBUG
                        print("LocalHomepageServer: port 8000 busy, falling back to ephemeral port")
#endif
                        listener.cancel()
                        self.listener = nil
                        self.startListener(preferPort8000: false)
                        return
                    }
                    DispatchQueue.main.async {
                        self.url = nil
                    }
                default:
                    break
                }
            }

            listener.start(queue: queue)
        } catch {
            DispatchQueue.main.async {
                self.url = nil
            }
        }
    }

    private static func isAddressInUse(_ error: NWError) -> Bool {
        switch error {
        case .posix(let code):
            return code == .EADDRINUSE
        default:
            return false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async {
            self.url = nil
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)

        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                self.close(connection, error: error)
                return
            }

            var nextBuffer = buffer
            if let data, !data.isEmpty {
                nextBuffer.append(data)
            }

            if nextBuffer.count > 2_000_000 {
                let body = Data("payload too large\n".utf8)
                self.sendResponse(
                    statusLine: "HTTP/1.1 413 Payload Too Large",
                    headers: [
                        "Content-Type": "text/plain; charset=utf-8",
                        "Content-Length": "\(body.count)",
                        "Cache-Control": "no-store"
                    ],
                    body: body,
                    on: connection
                )
                return
            }

            if let request = Self.parseRequest(from: nextBuffer) {
                self.respond(to: request, on: connection)
                return
            }

            if isComplete {
                self.close(connection, error: nil)
                return
            }

            self.receiveRequest(on: connection, buffer: nextBuffer)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        let path = request.path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? request.path

        if request.method == "GET", path == "/" || path == "/Homepage.html" || path == "/Homepage" {
            let body = homepageHTML
            let headers = [
                "Content-Type": "text/html; charset=utf-8",
                "Content-Length": "\(body.count)",
                "Cache-Control": "no-store"
            ]
            sendResponse(statusLine: "HTTP/1.1 200 OK", headers: headers, body: body, on: connection)
            return
        }

        if request.method == "GET", path == "/health" {
            respondWithHealth(on: connection)
            return
        }

        if path.hasPrefix("/api/") {
            proxyToOllama(request: request, on: connection)
            return
        }

        if request.method == "GET", path == "/favicon.ico" {
            sendResponse(statusLine: "HTTP/1.1 204 No Content", headers: ["Cache-Control": "no-store"], body: Data(), on: connection)
            return
        }

        let body = Data("not found\n".utf8)
        sendResponse(
            statusLine: "HTTP/1.1 404 Not Found",
            headers: [
                "Content-Type": "text/plain; charset=utf-8",
                "Content-Length": "\(body.count)",
                "Cache-Control": "no-store"
            ],
            body: body,
            on: connection
        )
    }

    private func respondWithHealth(on connection: NWConnection) {
        let url = ollamaBaseURL
            .appendingPathComponent("api")
            .appendingPathComponent("version")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.0

        Task {
            var ok = false
            var errorMessage: String? = nil
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                ok = (200..<300).contains(status)
                if !ok {
                    errorMessage = "Ollama returned HTTP \(status)"
                }
            } catch {
                ok = false
                errorMessage = error.localizedDescription
            }

            var json: [String: Any] = ["ok": ok]
            if let errorMessage, !ok {
                json["error"] = errorMessage
            }

            let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{\"ok\":false}".utf8)
            queue.async { [weak self] in
                self?.sendResponse(
                    statusLine: "HTTP/1.1 200 OK",
                    headers: [
                        "Content-Type": "application/json; charset=utf-8",
                        "Content-Length": "\(body.count)",
                        "Cache-Control": "no-store"
                    ],
                    body: body,
                    on: connection
                )
            }
        }
    }

    private func proxyToOllama(request: HTTPRequest, on connection: NWConnection) {
        guard let url = URL(string: request.path, relativeTo: ollamaBaseURL) else {
            let body = Data("{\"error\":\"Invalid URL\"}".utf8)
            sendResponse(
                statusLine: "HTTP/1.1 400 Bad Request",
                headers: [
                    "Content-Type": "application/json; charset=utf-8",
                    "Content-Length": "\(body.count)",
                    "Cache-Control": "no-store"
                ],
                body: body,
                on: connection
            )
            return
        }

        var proxied = URLRequest(url: url)
        proxied.httpMethod = request.method
        proxied.httpBody = request.body.isEmpty ? nil : request.body
        proxied.timeoutInterval = 60

        if let contentType = request.headers["content-type"] {
            proxied.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let accept = request.headers["accept"] {
            proxied.setValue(accept, forHTTPHeaderField: "Accept")
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: proxied)
                let http = response as? HTTPURLResponse
                let statusCode = http?.statusCode ?? 502
                let reason = Self.reasonPhrase(for: statusCode)
                let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? "application/json; charset=utf-8"

                queue.async { [weak self] in
                    self?.sendResponse(
                        statusLine: "HTTP/1.1 \(statusCode) \(reason)",
                        headers: [
                            "Content-Type": contentType,
                            "Content-Length": "\(data.count)",
                            "Cache-Control": "no-store"
                        ],
                        body: data,
                        on: connection
                    )
                }
            } catch {
                let msg = error.localizedDescription.replacingOccurrences(of: "\"", with: "'")
                let body = Data("{\"error\":\"\(msg)\"}".utf8)
                queue.async { [weak self] in
                    self?.sendResponse(
                        statusLine: "HTTP/1.1 502 Bad Gateway",
                        headers: [
                            "Content-Type": "application/json; charset=utf-8",
                            "Content-Length": "\(body.count)",
                            "Cache-Control": "no-store"
                        ],
                        body: body,
                        on: connection
                    )
                }
            }
        }
    }

    private func sendResponse(statusLine: String, headers: [String: String], body: Data, on connection: NWConnection) {
        var head = "\(statusLine)\r\n"
        for (k, v) in headers {
            head += "\(k): \(v)\r\n"
        }
        head += "Connection: close\r\n\r\n"

        var payload = Data(head.utf8)
        payload.append(body)

        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func close(_ connection: NWConnection, error: NWError?) {
        connection.cancel()
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

private extension LocalHomepageServer {
    static func parseRequest(from data: Data) -> HTTPRequest? {
        guard let headerEnd = data.range(of: Data([13, 10, 13, 10])) else {
            return nil
        }

        let headData = data.subdata(in: data.startIndex..<headerEnd.lowerBound)
        guard let head = String(data: headData, encoding: .utf8) else {
            return nil
        }

        let lines = head.split(whereSeparator: \.isNewline).map(String.init)
        guard let requestLine = lines.first else {
            return nil
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        if lines.count > 1 {
            for line in lines.dropFirst() {
                guard let idx = line.firstIndex(of: ":") else { continue }
                let key = line[..<idx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    headers[key] = value
                }
            }
        }

        let contentLength = Int(headers["content-length"] ?? "") ?? 0
        let bodyStart = headerEnd.upperBound
        let bodyEnd = bodyStart + contentLength
        if contentLength > 0 {
            guard data.count >= bodyEnd else { return nil }
        }
        let body = contentLength > 0 ? data.subdata(in: bodyStart..<bodyEnd) : Data()

        return HTTPRequest(method: method, path: path, headers: headers, body: body)
    }

    static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 413: return "Payload Too Large"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }
}
