import XCTest
@testable import Shitter

final class ChatGPTOAuthTests: XCTestCase {
    @MainActor
    func testAuthorizeURLUsesFixedLocalhostRedirect() throws {
        let url = try ChatGPTOAuth.buildAuthorizeURL(
            state: "state-123",
            codeChallenge: "challenge-456",
            redirectURI: "http://localhost:1455/auth/callback"
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "auth.openai.com")
        XCTAssertEqual(components.path, "/oauth/authorize")
        XCTAssertEqual(query["redirect_uri"], "http://localhost:1455/auth/callback")
        XCTAssertEqual(query["scope"], "openid profile email offline_access")
        XCTAssertEqual(query["codex_cli_simplified_flow"], "true")
    }

    @MainActor
    func testValidateCallbackURLAcceptsLoopbackCallback() throws {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:1455/auth/callback?code=abc&state=xyz"))

        let components = try ChatGPTOAuth.validateCallbackURL(url)

        XCTAssertEqual(components.path, "/auth/callback")
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })["code"],
            "abc"
        )
    }

    @MainActor
    func testValidateCallbackURLRejectsCustomSchemeCallbacks() throws {
        let url = try XCTUnwrap(URL(string: "shitterauth://auth/callback?code=abc&state=xyz"))

        XCTAssertThrowsError(try ChatGPTOAuth.validateCallbackURL(url))
    }
}
