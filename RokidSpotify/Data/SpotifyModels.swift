import Foundation

// MARK: - Playback state

struct PlaybackState: Codable {
    let isPlaying:    Bool
    let progressMs:   Int?
    let item:         SpotifyTrack?
    let repeatState:  String?      // "off", "track", "context"
    let shuffleState: Bool?
    let device:       SpotifyDevice?

    enum CodingKeys: String, CodingKey {
        case isPlaying    = "is_playing"
        case progressMs   = "progress_ms"
        case item
        case repeatState  = "repeat_state"
        case shuffleState = "shuffle_state"
        case device
    }

    var progressFormatted: String {
        guard let ms = progressMs else { return "0:00" }
        return formatMs(ms)
    }

    var durationFormatted: String {
        guard let d = item?.durationMs else { return "0:00" }
        return formatMs(d)
    }

    var progressFraction: Double {
        guard let p = progressMs, let d = item?.durationMs, d > 0 else { return 0 }
        return Double(p) / Double(d)
    }

    private func formatMs(_ ms: Int) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Track

struct SpotifyTrack: Codable {
    let id:          String
    let name:        String
    let artists:     [SpotifyArtist]
    let album:       SpotifyAlbum
    let durationMs:  Int
    let explicit:    Bool
    let externalUrls: ExternalUrls?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, explicit
        case durationMs   = "duration_ms"
        case externalUrls = "external_urls"
    }

    var artistNames: String { artists.map(\.name).joined(separator: ", ") }

    var spotifyURL: URL? { externalUrls?.spotify.flatMap { URL(string: $0) } }
}

struct SpotifyArtist: Codable {
    let id:   String
    let name: String
}

struct SpotifyAlbum: Codable {
    let id:     String
    let name:   String
    let images: [SpotifyImage]

    var largestImage: SpotifyImage? { images.max(by: { ($0.width ?? 0) < ($1.width ?? 0) }) }
    var smallestImage: SpotifyImage? { images.min(by: { ($0.width ?? 0) < ($1.width ?? 0) }) }
}

struct SpotifyImage: Codable {
    let url:    String
    let width:  Int?
    let height: Int?
}

struct ExternalUrls: Codable {
    let spotify: String?
}

// MARK: - Device

struct SpotifyDevice: Codable {
    let id:           String?
    let name:         String
    let type:         String     // "Computer", "Smartphone", "Speaker"
    let isActive:     Bool
    let volumePercent: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case isActive      = "is_active"
        case volumePercent = "volume_percent"
    }

    var typeIcon: String {
        switch type.lowercased() {
        case "smartphone": return "iphone"
        case "computer":   return "laptopcomputer"
        case "speaker":    return "hifispeaker.fill"
        case "tv":         return "tv.fill"
        default:           return "airplayaudio"
        }
    }
}

// MARK: - Devices list

struct DevicesResponse: Codable {
    let devices: [SpotifyDevice]
}

// MARK: - Recently played

struct RecentlyPlayedResponse: Codable {
    let items: [PlayHistoryItem]
}

struct PlayHistoryItem: Codable {
    let track:    SpotifyTrack
    let playedAt: String

    enum CodingKeys: String, CodingKey {
        case track
        case playedAt = "played_at"
    }
}

// MARK: - Auth tokens

struct SpotifyTokens: Codable {
    var accessToken:  String
    var refreshToken: String
    var expiresAt:    Date

    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

struct SpotifyTokenResponse: Codable {
    let accessToken:  String
    let tokenType:    String
    let expiresIn:    Int
    let refreshToken: String?
    let scope:        String?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case tokenType    = "token_type"
        case expiresIn    = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Display format

enum GlassesFormat: String, CaseIterable, Identifiable {
    case compact, detailed, minimal
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// MARK: - Errors

enum SpotifyError: LocalizedError {
    case notAuthenticated
    case noActiveDevice
    case premiumRequired
    case apiError(Int, String)
    case authFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "Not authenticated. Please log in."
        case .noActiveDevice:    return "No active Spotify device found."
        case .premiumRequired:   return "Spotify Premium is required for playback control."
        case .apiError(let c, let m): return "API error \(c): \(m)"
        case .authFailed(let m): return "Auth failed: \(m)"
        }
    }
}
