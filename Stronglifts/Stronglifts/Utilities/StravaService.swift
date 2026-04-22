import Foundation
import Combine
import AuthenticationServices
import Security
#if canImport(UIKit)
import UIKit
#endif

final class StravaService: NSObject, ObservableObject {
    static let shared = StravaService()

    @Published var isConnected = false

    // MARK: - Keychain keys
    private let kAccessToken  = "strava_access_token"
    private let kRefreshToken = "strava_refresh_token"
    private let kExpiresAt    = "strava_expires_at"

    private var accessToken: String? {
        get { keychainGet(kAccessToken) }
        set { newValue.map { keychainSet(kAccessToken, $0) } ?? keychainDelete(kAccessToken) }
    }
    private var refreshToken: String? {
        get { keychainGet(kRefreshToken) }
        set { newValue.map { keychainSet(kRefreshToken, $0) } ?? keychainDelete(kRefreshToken) }
    }
    private var expiresAt: Date? {
        get {
            guard let s = keychainGet(kExpiresAt), let ts = Double(s) else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        set {
            newValue.map { keychainSet(kExpiresAt, String($0.timeIntervalSince1970)) }
                ?? keychainDelete(kExpiresAt)
        }
    }

    override init() {
        super.init()
        isConnected = accessToken != nil
    }

    // MARK: - Connect / Disconnect

    func connect() async throws {
        var comps = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        comps.queryItems = [
            .init(name: "client_id",       value: StravaConfig.clientID),
            .init(name: "redirect_uri",    value: StravaConfig.redirectURI),
            .init(name: "response_type",   value: "code"),
            .init(name: "approval_prompt", value: "auto"),
            .init(name: "scope",           value: StravaConfig.scope),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            var authSession: ASWebAuthenticationSession?
            authSession = ASWebAuthenticationSession(
                url: comps.url!,
                callbackURLScheme: "stronglifts"
            ) { url, error in
                _ = authSession
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: StravaError.noCallbackURL) }
            }
            authSession!.presentationContextProvider = self
            authSession!.prefersEphemeralWebBrowserSession = false
            authSession!.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw StravaError.missingCode }

        try await exchangeCode(code)
        isConnected = true
    }

    func disconnect() {
        accessToken  = nil
        refreshToken = nil
        expiresAt    = nil
        isConnected  = false
    }

    // MARK: - Post workout

    func postWorkout(_ session: WorkoutSession, duration: TimeInterval) async throws {
        let token = try await validToken()

        var lines = session.sortedLogs.map { log in
            let reps   = log.setLogs.first?.targetReps ?? 0
            let weight = Int(log.targetWeight)
            let flag   = log.wasSuccessful ? "" : " ⚠️"
            return "\(log.exerciseName): \(log.setLogs.count)×\(reps) @ \(weight) lbs\(flag)"
        }
        if let avg = session.averageHeartRate, let max = session.maxHeartRate {
            lines.append("❤️ Avg \(Int(avg.rounded())) bpm · Max \(max) bpm")
        }
        let description = lines.joined(separator: "\n")

        var body: [String: Any] = [
            "name":             "Workout \(session.templateName) — Stronglifts 5×5",
            "sport_type":       "WeightTraining",
            "start_date_local": localISO8601(session.date),
            "elapsed_time":     Int(duration),
            "description":      description,
        ]

        if let avg = session.averageHeartRate {
            body["average_heartrate"] = avg
        }
        if let max = session.maxHeartRate {
            body["max_heartrate"] = max
        }

        var req = URLRequest(url: URL(string: "https://www.strava.com/api/v3/activities")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)",  forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw StravaError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
    }

    // MARK: - Token management

    private func exchangeCode(_ code: String) async throws {
        let body: [String: String] = [
            "client_id":     StravaConfig.clientID,
            "client_secret": StravaConfig.clientSecret,
            "code":          code,
            "grant_type":    "authorization_code",
        ]
        storeTokens(try await tokenRequest(body: body))
    }

    private func refreshAccessToken() async throws {
        guard let rt = refreshToken else { throw StravaError.notConnected }
        let body: [String: String] = [
            "client_id":     StravaConfig.clientID,
            "client_secret": StravaConfig.clientSecret,
            "refresh_token": rt,
            "grant_type":    "refresh_token",
        ]
        storeTokens(try await tokenRequest(body: body))
    }

    private func tokenRequest(body: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func storeTokens(_ r: TokenResponse) {
        accessToken  = r.accessToken
        refreshToken = r.refreshToken
        expiresAt    = Date(timeIntervalSince1970: TimeInterval(r.expiresAt))
    }

    private func validToken() async throws -> String {
        if let exp = expiresAt, exp > Date().addingTimeInterval(60), let token = accessToken {
            return token
        }
        try await refreshAccessToken()
        guard let token = accessToken else { throw StravaError.notConnected }
        return token
    }

    // MARK: - Keychain

    private func keychainSet(_ key: String, _ value: String) {
        let data  = value.data(using: .utf8)!
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: key,
                     kSecValueData: data] as CFDictionary
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }

    private func keychainGet(_ key: String) -> String? {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: key,
                     kSecReturnData: true,
                     kSecMatchLimit: kSecMatchLimitOne] as CFDictionary
        var result: AnyObject?
        guard SecItemCopyMatching(query, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(_ key: String) {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: key] as CFDictionary
        SecItemDelete(query)
    }
}

// MARK: - Presentation context

extension StravaService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

// MARK: - Supporting types

enum StravaError: LocalizedError {
    case noCallbackURL, missingCode, notConnected, apiError(String)

    var errorDescription: String? {
        switch self {
        case .noCallbackURL:   return "No callback URL from Strava"
        case .missingCode:     return "Missing authorization code"
        case .notConnected:    return "Not connected to Strava"
        case .apiError(let m): return "Strava: \(m)"
        }
    }
}

private func localISO8601(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.timeZone = .current
    return f.string(from: date)
}

private struct TokenResponse: Decodable {
    let accessToken:  String
    let refreshToken: String
    let expiresAt:    Int
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt    = "expires_at"
    }
}
