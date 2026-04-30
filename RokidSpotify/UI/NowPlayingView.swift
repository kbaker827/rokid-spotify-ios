import SwiftUI
import AuthenticationServices

struct NowPlayingView: View {
    @EnvironmentObject private var vm: SpotifyViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            if !settings.isLoggedIn {
                loginView
            } else {
                playerView
            }
        }
    }

    // MARK: - Login

    private var loginView: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33)) // Spotify green

            Text("Rokid Spotify HUD")
                .font(.largeTitle.bold())
            Text("Stream what's playing to your Rokid AR glasses.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if settings.clientId.isEmpty {
                Label("Enter your Client ID in Settings first.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }

            Button {
                Task { await vm.login(anchor: UIWindow()) }
            } label: {
                HStack {
                    Image(systemName: "music.note").font(.title3)
                    Text("Log in with Spotify").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.11, green: 0.73, blue: 0.33))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 30))
            }
            .padding(.horizontal, 40)
            .disabled(settings.clientId.isEmpty || vm.isLoading)

            if vm.isLoading { ProgressView() }
            if let err = vm.error {
                Text(err).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
            }
        }
        .padding()
    }

    // MARK: - Player

    private var playerView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let state = vm.playbackState, let track = state.item {
                    // Album art placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.3), Color.black.opacity(0.5)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(width: 260, height: 260)
                    .padding(.top)

                    // Track info
                    VStack(spacing: 4) {
                        Text(track.name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(track.artistNames)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if settings.showAlbum {
                            Text(track.album.name)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        if track.explicit {
                            Text("E")
                                .font(.caption2.bold())
                                .padding(3)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .padding(.horizontal)

                    // Progress bar
                    if settings.showProgress {
                        VStack(spacing: 4) {
                            ProgressView(value: state.progressFraction)
                                .tint(Color(red: 0.11, green: 0.73, blue: 0.33))
                                .padding(.horizontal)
                            HStack {
                                Text(state.progressFormatted)
                                Spacer()
                                Text(state.durationFormatted)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        }
                    }

                    // Controls
                    HStack(spacing: 40) {
                        // Shuffle
                        Button { Task { await vm.toggleShuffle() } } label: {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                .foregroundStyle(state.shuffleState == true ? Color(red:0.11,green:0.73,blue:0.33) : .secondary)
                        }

                        // Previous
                        Button { Task { await vm.previousTrack() } } label: {
                            Image(systemName: "backward.fill").font(.title)
                        }

                        // Play / Pause
                        Button { Task { await vm.togglePlayPause() } } label: {
                            Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33))
                        }

                        // Next
                        Button { Task { await vm.nextTrack() } } label: {
                            Image(systemName: "forward.fill").font(.title)
                        }

                        // Repeat
                        Button { Task { await vm.cycleRepeat() } } label: {
                            let r = state.repeatState ?? "off"
                            Image(systemName: r == "track" ? "repeat.1" : "repeat")
                                .font(.title3)
                                .foregroundStyle(r != "off" ? Color(red:0.11,green:0.73,blue:0.33) : .secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    // Device
                    if let device = state.device {
                        HStack(spacing: 6) {
                            Image(systemName: device.typeIcon)
                            Text("Playing on \(device.name)")
                            if let vol = device.volumePercent {
                                Text("· \(vol)%")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                } else {
                    ContentUnavailableView(
                        "Nothing Playing",
                        systemImage: "pause.circle",
                        description: Text("Open Spotify and start playing something.")
                    )
                    .padding(.top, 60)
                }

                // Glasses status
                HStack(spacing: 6) {
                    Circle().fill(vm.glassesClientCount > 0 ? Color.green : Color.gray).frame(width: 8, height: 8)
                    Text("TCP :8094  ·  \(vm.glassesClientCount) client(s)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Recent
                if !vm.recentTracks.isEmpty {
                    GroupBox("Recently Played") {
                        ForEach(vm.recentTracks.prefix(5), id: \.track.id) { item in
                            HStack {
                                Image(systemName: "music.note").foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(item.track.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                    Text(item.track.artistNames).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle("Now Playing")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.fetchPlayback(); await vm.fetchRecentTracks() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await vm.fetchPlayback()
            await vm.fetchRecentTracks()
        }
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(SpotifyViewModel())
        .environmentObject(SettingsStore.shared)
}
