import Foundation
import CryptoKit
import Security

enum OAuthError: LocalizedError {
    case randomFailure, invalidCallback, invalidState, denied, configuration, missingToken, keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .randomFailure: return "Не удалось создать безопасный запрос."
        case .invalidCallback: return "Неверный адрес OAuth callback."
        case .invalidState: return "Проверка OAuth state не пройдена. Войдите заново."
        case .denied: return "Авторизация отменена или отклонена."
        case .configuration: return "Настройте Client ID и зарегистрированный callback Spotify. Для HTTPS нужны Associated Domains."
        case .missingToken: return "Необходим повторный вход в Spotify."
        case .keychain: return "Хранилище недоступно. Проверьте подпись и разблокируйте iPhone."
        }
    }
}

struct PKCE {
    static func randomString(bytes count: Int = 32) throws -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { throw OAuthError.randomFailure }
        return base64URL(Data(bytes))
    }
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }
    static func authorizationURL(config: AppConfiguration, verifier: String, state: String) -> URL {
        var parts = URLComponents(string: "https://accounts.spotify.com/authorize")!
        parts.queryItems = ["client_id": config.clientID, "response_type": "code", "redirect_uri": config.redirectURI,
                            "scope": "user-read-playback-state user-modify-playback-state",
                            "state": state, "code_challenge_method": "S256", "code_challenge": challenge(verifier)]
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return parts.url!
    }
    static func code(from url: URL, redirect: URL, state: String) throws -> String {
        guard url.scheme == redirect.scheme, url.host == redirect.host, url.port == redirect.port,
              url.path == redirect.path, url.fragment == nil,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw OAuthError.invalidCallback }
        let items = parts.queryItems ?? []
        func values(_ key: String) -> [String] { items.filter { $0.name == key }.compactMap(\.value) }
        guard values("state") == [state] else { throw OAuthError.invalidState }
        guard values("error").isEmpty else { throw OAuthError.denied }
        guard values("code").count == 1, let code = values("code").first, !code.isEmpty else { throw OAuthError.invalidCallback }
        return code
    }
}
