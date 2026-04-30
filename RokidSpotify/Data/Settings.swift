import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Key {
        static let clientId      = "spotify_client_id"
        static let glassesFormat = "glasses_format"
        static let pollInterval  = "poll_interval"
        static let showAlbum     = "show_album"
        static let showProgress  = "show_progress"
        static let alertTrack    = "alert_track_change"
        static let tokens        = "spotify_tokens"
    }

    @Published var clientId: String {
        didSet { UserDefaults.standard.set(clientId, forKey: Key.clientId) }
    }
    @Published var glassesFormat: GlassesFormat {
        didSet { UserDefaults.standard.set(glassesFormat.rawValue, forKey: Key.glassesFormat) }
    }
    @Published var pollInterval: Double {
        didSet { UserDefaults.standard.set(pollInterval, forKey: Key.pollInterval) }
    }
    @Published var showAlbum: Bool {
        didSet { UserDefaults.standard.set(showAlbum, forKey: Key.showAlbum) }
    }
    @Published var showProgress: Bool {
        didSet { UserDefaults.standard.set(showProgress, forKey: Key.showProgress) }
    }
    @Published var alertTrackChange: Bool {
        didSet { UserDefaults.standard.set(alertTrackChange, forKey: Key.alertTrack) }
    }

    // Tokens stored in UserDefaults (production app should use Keychain)
    var tokens: SpotifyTokens? {
        get {
            guard let d = UserDefaults.standard.data(forKey: Key.tokens) else { return nil }
            return try? JSONDecoder().decode(SpotifyTokens.self, from: d)
        }
        set {
            if let t = newValue, let d = try? JSONEncoder().encode(t) {
                UserDefaults.standard.set(d, forKey: Key.tokens)
            } else {
                UserDefaults.standard.removeObject(forKey: Key.tokens)
            }
            objectWillChange.send()
        }
    }

    var isLoggedIn: Bool { tokens != nil }

    static let redirectURI = "rokidspotify://callback"
    static let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        "user-read-recently-played"
    ].joined(separator: " ")

    private init() {
        let ud = UserDefaults.standard
        clientId     = ud.string(forKey: Key.clientId)    ?? ""
        pollInterval = ud.object(forKey: Key.pollInterval) as? Double ?? 5
        showAlbum    = ud.object(forKey: Key.showAlbum)    as? Bool ?? true
        showProgress = ud.object(forKey: Key.showProgress) as? Bool ?? true
        alertTrackChange = ud.object(forKey: Key.alertTrack) as? Bool ?? true
        if let raw = ud.string(forKey: Key.glassesFormat),
           let fmt = GlassesFormat(rawValue: raw) {
            glassesFormat = fmt
        } else {
            glassesFormat = .compact
        }
    }

    func logout() {
        tokens = nil
    }
}
