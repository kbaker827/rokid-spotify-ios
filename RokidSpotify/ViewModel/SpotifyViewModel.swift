import Foundation
import Combine

@MainActor
final class SpotifyViewModel: ObservableObject {

    @Published private(set) var playbackState: PlaybackState?
    @Published private(set) var recentTracks: [PlayHistoryItem] = []
    @Published private(set) var devices: [SpotifyDevice] = []
    @Published private(set) var isLoading  = false
    @Published private(set) var error: String?
    @Published private(set) var glassesClientCount = 0

    let settings      = SettingsStore.shared
    let authManager   = SpotifyAuthManager()
    private let api   = SpotifyAPIClient()
    private let glasses = GlassesServer()

    private var pollTimer:  Timer?
    private var prevTrackId: String?

    init() {
        glasses.start()
        if settings.isLoggedIn { startPolling() }
    }

    deinit { pollTimer?.invalidate() }

    // MARK: - Auth

    func login(anchor: Any) async {
        guard !settings.clientId.isEmpty else {
            error = "Enter your Spotify Client ID in Settings first."
            return
        }
        isLoading = true
        error     = nil
        do {
            // anchor is ASPresentationAnchor but we keep it Any to avoid UIKit import here
            try await authManager.login(presentationAnchor: anchor as! (any Sendable) as! ASPresentationAnchorWrapper)
            startPolling()
            await fetchPlayback()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        stopPolling()
        settings.logout()
        playbackState = nil
        recentTracks  = []
        devices       = []
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: settings.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.fetchPlayback() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func restartPolling() {
        stopPolling()
        if settings.isLoggedIn { startPolling() }
    }

    // MARK: - Fetch playback

    func fetchPlayback() async {
        guard settings.isLoggedIn else { return }
        do {
            let token = try await authManager.refreshIfNeeded()
            let state = try await api.currentlyPlaying(token: token)
            playbackState = state
            glassesClientCount = glasses.clientCount

            if let state {
                glasses.broadcastPlayback(state, settings: settings)
                checkTrackChange(state)
            } else {
                glasses.broadcastPaused()
            }
        } catch SpotifyError.notAuthenticated {
            settings.logout()
            stopPolling()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Controls

    func togglePlayPause() async {
        guard let state = playbackState else { return }
        do {
            let token = try await authManager.refreshIfNeeded()
            if state.isPlaying { try await api.pause(token: token) }
            else               { try await api.play(token: token) }
            await fetchPlayback()
        } catch { self.error = error.localizedDescription }
    }

    func nextTrack() async {
        do {
            let token = try await authManager.refreshIfNeeded()
            try await api.nextTrack(token: token)
            try? await Task.sleep(for: .milliseconds(500))
            await fetchPlayback()
        } catch { self.error = error.localizedDescription }
    }

    func previousTrack() async {
        do {
            let token = try await authManager.refreshIfNeeded()
            try await api.previousTrack(token: token)
            try? await Task.sleep(for: .milliseconds(500))
            await fetchPlayback()
        } catch { self.error = error.localizedDescription }
    }

    func toggleShuffle() async {
        guard let state = playbackState else { return }
        do {
            let token = try await authManager.refreshIfNeeded()
            try await api.setShuffle(!(state.shuffleState ?? false), token: token)
            await fetchPlayback()
        } catch { self.error = error.localizedDescription }
    }

    func cycleRepeat() async {
        guard let state = playbackState else { return }
        let next: String
        switch state.repeatState ?? "off" {
        case "off":     next = "context"
        case "context": next = "track"
        default:        next = "off"
        }
        do {
            let token = try await authManager.refreshIfNeeded()
            try await api.setRepeat(next, token: token)
            await fetchPlayback()
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Recent tracks

    func fetchRecentTracks() async {
        guard settings.isLoggedIn else { return }
        do {
            let token = try await authManager.refreshIfNeeded()
            recentTracks = try await api.recentlyPlayed(token: token, limit: 20)
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Devices

    func fetchDevices() async {
        guard settings.isLoggedIn else { return }
        do {
            let token = try await authManager.refreshIfNeeded()
            devices = try await api.devices(token: token)
        } catch { self.error = error.localizedDescription }
    }

    // MARK: - Track change alert

    private func checkTrackChange(_ state: PlaybackState) {
        guard settings.alertTrackChange,
              let track = state.item else { return }
        if prevTrackId != track.id {
            prevTrackId = track.id
            let text = "♪ \(track.name) — \(track.artistNames)"
            glasses.broadcastAlert(text: text)
        }
    }
}

// Shim to avoid importing AuthenticationServices in the ViewModel
typealias ASPresentationAnchorWrapper = AnyObject
