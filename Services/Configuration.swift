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
        guard let url = URL(string: redirectURI), let scheme = url.scheme,
              let host = url.host, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, !url.path.isEmpty else { return nil }
        if scheme == "https" { guard !host.hasSuffix("example.com") else { return nil } }
        else { guard scheme == Self.nativeCallbackScheme, host == "spotify", url.path == "/callback", url.port == nil else { return nil } }
        return url
    }
    static let nativeCallbackScheme = "com.tomilenko95.carwidget"
    static var personalSpotify: Bool {
        #if PERSONAL_SPOTIFY
        return true
        #else
        return false
        #endif
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
