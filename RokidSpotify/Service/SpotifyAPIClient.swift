import Foundation

// MARK: - Spotify Web API Client

actor SpotifyAPIClient {

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        return URLSession(configuration: cfg)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Playback

    /// Returns nil when nothing is playing.
    func currentlyPlaying(token: String) async throws -> PlaybackState? {
        let (data, resp) = try await get("/me/player", token: token)
        guard let http = resp as? HTTPURLResponse else { return nil }
        if http.statusCode == 204 { return nil }   // no active playback
        try checkHTTP(http.statusCode, data: data)
        return try decoder.decode(PlaybackState.self, from: data)
    }

    func pause(token: String) async throws {
        try await put("/me/player/pause", token: token, body: nil)
    }

    func play(token: String) async throws {
        try await put("/me/player/play", token: token, body: nil)
    }

    func nextTrack(token: String) async throws {
        try await post("/me/player/next", token: token, body: nil)
    }

    func previousTrack(token: String) async throws {
        try await post("/me/player/previous", token: token, body: nil)
    }

    func setVolume(_ percent: Int, token: String) async throws {
        let url = "/me/player/volume?volume_percent=\(percent)"
        try await put(url, token: token, body: nil)
    }

    func setShuffle(_ on: Bool, token: String) async throws {
        try await put("/me/player/shuffle?state=\(on)", token: token, body: nil)
    }

    func setRepeat(_ mode: String, token: String) async throws {
        // mode: "off", "track", "context"
        try await put("/me/player/repeat?state=\(mode)", token: token, body: nil)
    }

    // MARK: - Devices

    func devices(token: String) async throws -> [SpotifyDevice] {
        let (data, resp) = try await get("/me/player/devices", token: token)
        try checkHTTP((resp as? HTTPURLResponse)?.statusCode ?? 0, data: data)
        return try decoder.decode(DevicesResponse.self, from: data).devices
    }

    // MARK: - Recently played

    func recentlyPlayed(token: String, limit: Int = 10) async throws -> [PlayHistoryItem] {
        let (data, resp) = try await get("/me/player/recently-played?limit=\(limit)", token: token)
        try checkHTTP((resp as? HTTPURLResponse)?.statusCode ?? 0, data: data)
        return try decoder.decode(RecentlyPlayedResponse.self, from: data).items
    }

    // MARK: - Private helpers

    private let base = "https://api.spotify.com/v1"

    private func get(_ path: String, token: String) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: URL(string: base + path)!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await session.data(for: req)
    }

    private func post(_ path: String, token: String, body: [String: Any]?) async throws {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        try checkHTTP((resp as? HTTPURLResponse)?.statusCode ?? 0, data: data)
    }

    private func put(_ path: String, token: String, body: [String: Any]?) async throws {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code != 204 { try checkHTTP(code, data: data) }
    }

    private func checkHTTP(_ code: Int, data: Data) throws {
        switch code {
        case 200...299, 0: return
        case 401:  throw SpotifyError.notAuthenticated
        case 403:  throw SpotifyError.premiumRequired
        case 404:  throw SpotifyError.noActiveDevice
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SpotifyError.apiError(code, msg.prefix(200).description)
        }
    }
}
