import AuthenticationServices
import UIKit

@MainActor
final class SpotifyAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var pending: CheckedContinuation<URL, Error>?
    func login(service: SpotifyPlaybackService, config: AppConfiguration = .current) async throws {
        guard config.canAuthenticate, let redirect = config.callbackURL, let host = redirect.host else { throw OAuthError.configuration }
        guard session == nil else { throw APIError.busy }
        let verifier = try PKCE.randomString()
        let state = try PKCE.randomString()
        let url = PKCE.authorizationURL(config: config, verifier: verifier, state: state)
        let callback: URL = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                pending = continuation
                let completion: ASWebAuthenticationSession.CompletionHandler = { [weak self] url, error in
                    Task { @MainActor in self?.finish(url: url, error: error) }
                }
                let auth: ASWebAuthenticationSession
                if redirect.scheme == "https" {
                    auth = ASWebAuthenticationSession(url: url, callback: .https(host: host, path: redirect.path), completionHandler: completion)
                } else {
                    auth = ASWebAuthenticationSession(url: url, callbackURLScheme: AppConfiguration.nativeCallbackScheme, completionHandler: completion)
                }
                auth.presentationContextProvider = self
                auth.prefersEphemeralWebBrowserSession = true
                session = auth
                if !auth.start() { finish(url: nil, error: OAuthError.denied) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
        try Task.checkCancellation()
        let code = try PKCE.code(from: callback, redirect: redirect, state: state)
        try await service.accept(code: code, verifier: verifier)
    }
    private func finish(url: URL?, error: Error?) {
        let continuation = pending; pending = nil; session = nil
        if let url { continuation?.resume(returning: url) }
        else { continuation?.resume(throwing: error ?? OAuthError.denied) }
    }
    func cancel() { session?.cancel(); finish(url: nil, error: CancellationError()) }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
