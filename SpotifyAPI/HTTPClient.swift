import Foundation

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession
    init(session: URLSession = URLSessionTransport.defaultSession) { self.session = session }
    static func makeSession(requestTimeout: TimeInterval, resourceTimeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        config.urlCache = nil
        return URLSession(configuration: config)
    }
    static let defaultSession = makeSession(requestTimeout: 8, resourceTimeout: 15)
    static let widgetSession = makeSession(requestTimeout: 3, resourceTimeout: 4)
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, response)
    }
}

enum APIError: LocalizedError {
    case unauthorized, forbidden, noDevice, actionUnavailable, rateLimited(Date), server(Int), invalidResponse, busy, storage
    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Сессия истекла. Войдите в Spotify заново."
        case .forbidden: return "Spotify отказал в доступе. Проверьте Premium, allowlist и разрешения приложения."
        case .noDevice: return "Откройте Spotify и начните воспроизведение на активном устройстве."
        case .actionUnavailable: return "Spotify не разрешает эту команду в текущем контексте."
        case .rateLimited(let date): return "Лимит Spotify. Повторите после \(date.formatted(date: .omitted, time: .standard))."
        case .server(let status): return "Spotify временно недоступен (HTTP \(status))."
        case .invalidResponse: return "Некорректный ответ сервера."
        case .busy: return "Обновление уже выполняется. Повторите позже."
        case .storage: return "Нет доступа к общему хранилищу. Проверьте App Group и provisioning profiles."
        }
    }
}

struct HTTPClient: Sendable {
    var transport: any HTTPTransport = URLSessionTransport()
    var sleep: @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    var maxReadRetries = 2
    static var widget: HTTPClient {
        HTTPClient(transport: URLSessionTransport(session: URLSessionTransport.widgetSession), maxReadRetries: 0)
    }
    static func retryDate(_ value: String?, now: Date = Date()) -> Date {
        if let value, let seconds = TimeInterval(value) { return now.addingTimeInterval(max(1, seconds)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return value.flatMap { formatter.date(from: $0) }.map { max(now.addingTimeInterval(1), $0) } ?? now.addingTimeInterval(60)
    }
    func send(_ request: URLRequest, retryRead: Bool = false) async throws -> (Data, HTTPURLResponse) {
        let retries = retryRead ? max(0, min(maxReadRetries, 2)) : 0
        for attempt in 0...retries {
            try Task.checkCancellation()
            let result: (Data, HTTPURLResponse)
            do { result = try await transport.data(for: request) }
            catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
                guard attempt < retries else { throw error }
                try await sleep(UInt64(350_000_000 * (1 << attempt)))
                continue
            }
            switch result.1.statusCode {
            case 200..<300: return result
            case 401: throw APIError.unauthorized
            case 403: throw APIError.forbidden
            case 404: throw APIError.noDevice
            case 429: throw APIError.rateLimited(Self.retryDate(result.1.value(forHTTPHeaderField: "Retry-After")))
            case 500...599 where attempt < retries:
                try await sleep(UInt64(350_000_000 * (1 << attempt)) + UInt64.random(in: 0...100_000_000))
            default: throw APIError.server(result.1.statusCode)
            }
        }
        throw APIError.invalidResponse
    }
    static func form(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(fields.sorted(by: { $0.key < $1.key }).map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").utf8)
    }
}
