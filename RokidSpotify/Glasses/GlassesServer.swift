import Foundation
import Network

@MainActor
final class GlassesServer {

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private(set) var clientCount = 0

    func start() {
        guard listener == nil else { return }
        do { listener = try NWListener(using: .tcp, on: 8094) } catch { return }
        listener?.stateUpdateHandler = { [weak self] state in
            if case .failed = state { Task { @MainActor [weak self] in self?.restart() } }
        }
        listener?.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in self?.accept(conn) }
        }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }; connections.removeAll(); clientCount = 0
    }

    private func restart() {
        stop()
        Task { @MainActor in try? await Task.sleep(for: .seconds(3)); self.start() }
    }

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.connections.append(conn)
                    self?.clientCount = self?.connections.count ?? 0
                case .failed, .cancelled:
                    self?.connections.removeAll { $0 === conn }
                    self?.clientCount = self?.connections.count ?? 0
                default: break
                }
            }
        }
        conn.start(queue: .main)
    }

    private func broadcast(_ text: String) {
        guard !connections.isEmpty else { return }
        let data = (text + "\n").data(using: .utf8)!
        connections.forEach { $0.send(content: data, completion: .contentProcessed { _ in }) }
    }

    func broadcastPlayback(_ state: PlaybackState, settings: SettingsStore) {
        let text = formatPlayback(state, settings: settings)
        if let json = try? JSONSerialization.data(withJSONObject: [
            "type": "playback",
            "text": text,
            "playing": state.isPlaying
        ]), let str = String(data: json, encoding: .utf8) { broadcast(str) }
    }

    func broadcastAlert(text: String) {
        if let json = try? JSONSerialization.data(withJSONObject: ["type": "alert", "text": text]),
           let str = String(data: json, encoding: .utf8) { broadcast(str) }
    }

    func broadcastPaused() {
        if let json = try? JSONSerialization.data(withJSONObject: ["type": "playback", "text": "⏸ Paused", "playing": false]),
           let str = String(data: json, encoding: .utf8) { broadcast(str) }
    }

    private func formatPlayback(_ state: PlaybackState, settings: SettingsStore) -> String {
        guard let track = state.item else { return "Nothing playing" }
        let playIcon = state.isPlaying ? "▶" : "⏸"

        switch settings.glassesFormat {
        case .compact:
            var parts = ["\(playIcon) \(track.name) — \(track.artistNames)"]
            if settings.showProgress {
                parts.append("\(state.progressFormatted)/\(state.durationFormatted)")
            }
            return parts.joined(separator: "  |  ")

        case .detailed:
            var lines = ["\(playIcon) \(track.name)"]
            lines.append("🎤 \(track.artistNames)")
            if settings.showAlbum { lines.append("💿 \(track.album.name)") }
            if settings.showProgress {
                let pct = Int(state.progressFraction * 100)
                lines.append("⏱ \(state.progressFormatted)/\(state.durationFormatted)  \(pct)%")
            }
            return lines.joined(separator: "\n")

        case .minimal:
            return "\(playIcon) \(track.name)"
        }
    }
}
