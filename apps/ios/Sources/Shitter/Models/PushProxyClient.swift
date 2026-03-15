import Foundation

actor PushProxyClient {
    static let baseURL = URL(string: "https://push.sigkitten.com")!

    struct RegisterBody: Encodable {
        let platform: String
        let pushToken: String
        let intervalSeconds: Int
        let ttlSeconds: Int
    }

    struct RegisterResponse: Decodable {
        let id: String
    }

    func register(pushToken: String, interval: Int = 30, ttl: Int = 7200) async throws -> String {
        let body = RegisterBody(platform: "ios", pushToken: pushToken, intervalSeconds: interval, ttlSeconds: ttl)
        let data = try await post(path: "/register", body: body)
        return try JSONDecoder().decode(RegisterResponse.self, from: data).id
    }

    func deregister(registrationId: String) async throws {
        _ = try await post(path: "/\(registrationId)/deregister", body: Empty())
    }

    private struct Empty: Encodable {}

    private func post<T: Encodable>(path: String, body: T) async throws -> Data {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
