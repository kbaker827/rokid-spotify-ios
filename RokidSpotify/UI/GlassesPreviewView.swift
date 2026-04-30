import SwiftUI

struct GlassesPreviewView: View {
    @EnvironmentObject private var vm: SpotifyViewModel
    @EnvironmentObject private var settings: SettingsStore

    private var previewLines: [String] {
        guard let state = vm.playbackState, let track = state.item else {
            return ["Nothing playing"]
        }
        let play = state.isPlaying ? "▶" : "⏸"
        switch settings.glassesFormat {
        case .compact:
            var parts = ["\(play) \(track.name) — \(track.artistNames)"]
            if settings.showProgress {
                parts.append("\(state.progressFormatted)/\(state.durationFormatted)")
            }
            return [parts.joined(separator: "  |  ")]
        case .detailed:
            var lines = ["\(play) \(track.name)", "🎤 \(track.artistNames)"]
            if settings.showAlbum { lines.append("💿 \(track.album.name)") }
            if settings.showProgress {
                let pct = Int(state.progressFraction * 100)
                lines.append("⏱ \(state.progressFormatted)/\(state.durationFormatted)  \(pct)%")
            }
            return lines
        case .minimal:
            return ["\(play) \(track.name)"]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { f in Text(f.displayName).tag(f) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal)

                    Toggle("Show album", isOn: $settings.showAlbum).padding(.horizontal)
                    Toggle("Show progress", isOn: $settings.showProgress).padding(.horizontal)

                    // Mockup
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10).fill(Color.black)
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(previewLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33))
                                    .lineLimit(2)
                            }
                        }.padding(12)
                    }
                    .aspectRatio(16/4, contentMode: .fit)
                    .padding(.horizontal)

                    HStack(spacing: 6) {
                        Circle().fill(vm.glassesClientCount > 0 ? Color.green : Color.gray).frame(width: 8, height: 8)
                        Text("TCP :8094  —  \(vm.glassesClientCount) client(s)")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    GroupBox("Raw JSON") {
                        let dict: [String: Any] = [
                            "type":    "playback",
                            "text":    previewLines.joined(separator: "\n"),
                            "playing": vm.playbackState?.isPlaying ?? false
                        ]
                        let json = (try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted))
                            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(json)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                        }
                    }.padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Glasses Preview")
        }
    }
}
