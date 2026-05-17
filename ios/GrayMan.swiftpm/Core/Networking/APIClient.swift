import Foundation

// MARK: - Configuration

enum APIConfig {
    /// Base URL of the GrayMan FastAPI backend.
    ///
    /// Resolution order (first hit wins):
    ///   1. `API_BASE_URL` process-environment variable — set via Xcode's
    ///      Scheme editor for ad-hoc debug runs against a non-default host.
    ///   2. `API_BASE_URL` Info.plist key — populated per build configuration
    ///      so debug / staging / prod each ship with their own URL.
    ///   3. The hardcoded dev fallback below (LAN address of the Mac
    ///      running `docker compose up`).
    ///
    /// ATS exception: HTTP loads to a private IP normally trip App Transport
    /// Security on iOS. The bundled `Info.plist` sets
    /// `NSAllowsLocalNetworking = true` so requests to RFC-1918 hosts succeed
    /// without arbitrary-loads being enabled globally. Production builds
    /// MUST point at an `https://` host so ATS is satisfied.
    static let baseURL: URL = {
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !env.isEmpty,
           let url = URL(string: env) {
            return url
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !plist.isEmpty,
           let url = URL(string: plist) {
            return url
        }
        // Compile-time fallback — keep in sync with `Info.plist`. Used only
        // when neither override path returns a value (effectively never in a
        // bundled build, but safe for previews / unit tests).
        return URL(string: "http://192.168.1.38:8000/api/v1")!
    }()

    /// Absolute fallback when CoreLocation is denied/unavailable. Coarse
    /// city-centre coordinates so a profile screen never shows "0 km away"
    /// because of a missing fix. `LocationService` uses this as the last
    /// rung of its fallback ladder; it is not the "default user location"
    /// any more.
    static let defaultLat: Double = 19.0760
    static let defaultLng: Double = 72.8777
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case transport(URLError)
    case server(status: Int, body: String)
    case decoding(Error)
    case unauthorized
    case noToken
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:                       return "Invalid request URL"
        case .transport(let e):                 return "Network error: \(e.localizedDescription)"
        case .server(let status, let body):     return "Server returned \(status): \(body)"
        case .decoding(let e):                  return "Couldn't read server response: \(e.localizedDescription)"
        case .unauthorized:                     return "Your session has expired. Please sign in again."
        case .noToken:                          return "You must sign in first."
        case .unknown(let e):                   return "Unexpected error: \(e.localizedDescription)"
        }
    }
}

// MARK: - Token store

/// Thread-safe holder for the auth JWT. Backed by Keychain so the token
/// survives app restarts.
@MainActor
final class TokenStore {
    static let shared = TokenStore()

    private let service = "com.grayman.app.auth"
    private let account = "jwt"
    private var cached: String?

    private init() {
        cached = readKeychain()
    }

    var token: String? { cached }
    var workerID: String? {
        get { UserDefaults.standard.string(forKey: "grayman.workerID") }
        set { UserDefaults.standard.set(newValue, forKey: "grayman.workerID") }
    }

    func save(_ token: String) {
        cached = token
        writeKeychain(token)
    }

    func clear() {
        cached = nil
        deleteKeychain()
        workerID = nil
    }

    // MARK: Keychain plumbing

    private func keychainQuery() -> [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func readKeychain() -> String? {
        var q = keychainQuery()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeKeychain(_ token: String) {
        deleteKeychain()
        var q = keychainQuery()
        q[kSecValueData as String] = token.data(using: .utf8) ?? Data()
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    private func deleteKeychain() {
        SecItemDelete(keychainQuery() as CFDictionary)
    }
}

// MARK: - APIClient

/// Lightweight URLSession wrapper. Every request goes through `request(...)`
/// which handles JSON encoding/decoding, auth headers, and standardised
/// error mapping.
@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Set by the client when a request takes longer than `slowThresholdSec`
    /// to first byte — the UI can read it and show a "slow connection" hint
    /// without polling individual requests.
    private(set) var isSlowConnection: Bool = false
    private let slowThresholdSec: TimeInterval = 5
    /// Retry once on transient transport errors for idempotent GETs.
    /// Mutations are NOT retried automatically — duplicate POSTs would be
    /// worse than a clear error message.
    private let getRetries: Int = 1

    private init(session: URLSession? = nil) {
        // Tier-3 networks (30–50 kbps) need patient per-request timeouts.
        // Resource timeout is what governs a long-running upload streaming
        // multiple parts.
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = session ?? URLSession(configuration: config)

        encoder = JSONEncoder()
        decoder = JSONDecoder()
        // Every DTO declares explicit CodingKeys. Don't enable a global
        // snake/camel conversion strategy — it conflicts with the explicit
        // raw values and silently breaks decoding.
        // FastAPI emits ISO-8601 with fractional seconds; iso8601 doesn't
        // accept them, so use a custom strategy that tries both forms.
        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            if let parsed = ISO8601DateFormatter.fractional.date(from: raw) { return parsed }
            if let parsed = ISO8601DateFormatter.plain.date(from: raw) { return parsed }
            throw DecodingError.dataCorruptedError(in: try d.singleValueContainer(),
                                                   debugDescription: "Invalid ISO-8601 date: \(raw)")
        }
    }

    enum Method: String { case GET, POST, PUT, DELETE }

    // MARK: Generic request

    func request<Out: Decodable>(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> Out {
        let data = try await rawRequest(method, path, query: query, body: body, authenticated: authenticated)
        if Out.self == EmptyResponse.self {
            return EmptyResponse() as! Out
        }
        do {
            return try decoder.decode(Out.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Variant for endpoints with no response body (or where the caller
    /// doesn't care about the body).
    func requestVoid(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws {
        _ = try await rawRequest(method, path, query: query, body: body, authenticated: authenticated)
    }

    private func rawRequest(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem],
        body: (any Encodable)?,
        authenticated: Bool
    ) async throws -> Data {
        guard var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated {
            guard let token = TokenStore.shared.token else { throw APIError.noToken }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                req.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw APIError.unknown(error)
            }
        }

        return try await sendWithRetry(req, method: method)
    }

    private func sendWithRetry(_ req: URLRequest, method: Method) async throws -> Data {
        // Only GETs are auto-retried. POSTs would re-double-submit forms.
        let attempts = method == .GET ? (getRetries + 1) : 1
        var lastError: Error?
        for attempt in 1...attempts {
            let start = Date()
            do {
                let (data, response) = try await session.data(for: req)
                let elapsed = Date().timeIntervalSince(start)
                isSlowConnection = elapsed > slowThresholdSec
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.unknown(NSError(domain: "APIClient", code: -1))
                }
                switch http.statusCode {
                case 200..<300:
                    return data
                case 401:
                    TokenStore.shared.clear()
                    throw APIError.unauthorized
                default:
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw APIError.server(status: http.statusCode, body: body)
                }
            } catch let e as APIError {
                throw e
            } catch let e as URLError where _isTransientURLError(e) && attempt < attempts {
                // Network blip on Tier-3 — give it one more shot. Linear
                // backoff (0.6s) — exponential would multiply user wait too
                // aggressively when they're already on a slow link.
                lastError = e
                isSlowConnection = true
                try? await Task.sleep(nanoseconds: 600_000_000)
                continue
            } catch let e as URLError {
                throw APIError.transport(e)
            } catch {
                throw APIError.unknown(error)
            }
        }
        if let urlErr = lastError as? URLError {
            throw APIError.transport(urlErr)
        }
        throw APIError.unknown(lastError ?? NSError(domain: "APIClient", code: -2))
    }
}

/// URLError codes worth retrying — all transient (network down, timeout
/// on the wire, dropped connection). Codes like cancelled / badURL must
/// NOT be retried; the user (or developer) cancelled, retrying is futile.
private func _isTransientURLError(_ e: URLError) -> Bool {
    switch e.code {
    case .timedOut, .cannotConnectToHost, .networkConnectionLost,
         .notConnectedToInternet, .dnsLookupFailed,
         .resourceUnavailable, .secureConnectionFailed:
        return true
    default:
        return false
    }
}

// MARK: - Encodable erasure

struct EmptyResponse: Decodable { init() {} }

private struct AnyEncodable: Encodable {
    let wrapped: any Encodable
    init(_ wrapped: any Encodable) { self.wrapped = wrapped }
    func encode(to encoder: Encoder) throws { try wrapped.encode(to: encoder) }
}

// MARK: - Date formatters

// ISO8601DateFormatter is thread-safe for parsing once configured. The
// nonisolated(unsafe) attribute documents that contract for Swift 6.
private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
