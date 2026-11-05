import XCTest
@testable import SpotifyCarWidget

final class OAuthTests: XCTestCase {
    func testRFC7636Challenge() {
        XCTAssertEqual(PKCE.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
                       "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
    func testSecureVerifier() throws {
        let verifier = try PKCE.randomString()
        XCTAssertEqual(verifier.count, 43)
        XCTAssertTrue(verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        XCTAssertNotEqual(verifier, try PKCE.randomString())
    }
    func testAuthorizationRequestHasPKCEAndNoSecret() {
        let url = PKCE.authorizationURL(config: Fixtures.config, verifier: "verifier", state: "state")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name: "code_challenge_method", value: "S256")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "redirect_uri", value: Fixtures.config.redirectURI)))
        XCTAssertFalse(items.contains { $0.name.contains("secret") })
    }
    func testCallbackRequiresExactOriginPathAndState() throws {
        let redirect = Fixtures.config.callbackURL!
        XCTAssertEqual(try PKCE.code(from: URL(string: "\(redirect)?code=ok&state=expected")!, redirect: redirect, state: "expected"), "ok")
        for suffix in ["?code=ok&state=wrong", "?code=ok&state=expected&state=expected", "?state=expected", "?error=access_denied&state=expected"] {
            XCTAssertThrowsError(try PKCE.code(from: URL(string: "\(redirect)\(suffix)")!, redirect: redirect, state: "expected"))
        }
        for url in ["http://login.test.org/spotify/callback?code=ok&state=expected",
                    "https://evil.test.org/spotify/callback?code=ok&state=expected",
                    "https://login.test.org/other?code=ok&state=expected"] {
            XCTAssertThrowsError(try PKCE.code(from: URL(string: url)!, redirect: redirect, state: "expected"))
        }
    }
    func testFormEscapesReservedCharacters() {
        XCTAssertEqual(String(data: HTTPClient.form(["code": "a+b&c=d"]), encoding: .utf8), "code=a%2Bb%26c%3Dd")
    }
    func testRegisteredNativeCallbackAndStateValidation() throws {
        let config = AppConfiguration(clientID: Fixtures.config.clientID,
            redirectURI: "com.tomilenko95.carwidget://spotify/callback", appGroup: "", keychainGroup: nil)
        let redirect = try XCTUnwrap(config.callbackURL)
        XCTAssertEqual(try PKCE.code(from: URL(string: "\(redirect)?code=ok&state=expected")!, redirect: redirect, state: "expected"), "ok")
        XCTAssertThrowsError(try PKCE.code(from: URL(string: "com.tomilenko95.carwidget://evil/callback?code=ok&state=expected")!, redirect: redirect, state: "expected"))
        XCTAssertThrowsError(try PKCE.code(from: URL(string: "\(redirect)?code=ok&state=wrong")!, redirect: redirect, state: "expected"))
    }
    func testConfigurationRejectsUnregisteredNativeSchemeAndCredentials() {
        for redirect in ["random-app://spotify/callback", "com.tomilenko95.carwidget://spotify/other",
                         "com.tomilenko95.carwidget://spotify:80/callback", "https://user:password@login.test.org/spotify/callback"] {
            let config = AppConfiguration(clientID: Fixtures.config.clientID, redirectURI: redirect, appGroup: "", keychainGroup: nil)
            XCTAssertNil(config.callbackURL)
        }
    }
    func testCodeExchangeIncludesVerifierAndRetainsRefreshToken() async throws {
        let (api, mock, store) = Fixtures.api([.init(body: "{\"access_token\":\"new\",\"refresh_token\":\"r\",\"expires_in\":3600}")], store: MemoryTokens())
        try await api.tokens.exchange(code: "code", verifier: "verifier")
        let requests = await mock.requests
        let body = String(data: requests[0].httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("code_verifier=verifier"))
        XCTAssertTrue(body.contains("grant_type=authorization_code"))
        XCTAssertEqual(try store.read()?.refreshToken, "r")
    }
}
