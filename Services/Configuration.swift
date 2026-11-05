import Foundation

struct AppConfiguration: Sendable {
    let clientID: String
    let redirectURI: String
    let appGroup: String
    let keychainGroup: String?
    static var current: Self {
        let info = Bundle.main.infoDictionary ?? [:]
        return Self(clientID: info["SpotifyClientID"] as? String ?? "",
                    redirectURI: info["SpotifyRedirectURI"] as? String ?? "",
                    appGroup: info["AppGroup"] as? String ?? "",
                    keychainGroup: info["KeychainGroup"] as? String)
    }
    var callbackURL: URL? {
        guard let url = URL(string: redirectURI), url.scheme == "https",
              let host = url.host, !host.hasSuffix("example.com"),
              url.query == nil, url.fragment == nil, !url.path.isEmpty else { return nil }
        return url
    }
    var canAuthenticate: Bool {
        #if PERSONAL_DEMO
        return false
        #else
        return clientID.count == 32 && callbackURL != nil
        #endif
    }
    static var personalDemo: Bool {
        #if PERSONAL_DEMO
        return true
        #else
        return false
        #endif
    }
}
