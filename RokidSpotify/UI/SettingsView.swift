import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: SpotifyViewModel
    @EnvironmentObject private var settings: SettingsStore
    @State private var showClientId = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Spotify App") {
                    LabeledContent("Client ID") {
                        if showClientId {
                            TextField("abc123…", text: $settings.clientId)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            Text(settings.clientId.isEmpty ? "Not set" : "••••••••")
                                .foregroundStyle(settings.clientId.isEmpty ? .red : .secondary)
                        }
                    }
                    .onTapGesture { showClientId.toggle() }

                    Text("Redirect URI to register in your Spotify app dashboard:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(SettingsStore.redirectURI)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                        .textSelection(.enabled)

                    if settings.isLoggedIn {
                        Button(role: .destructive) { vm.logout() } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }

                Section("Poll Interval") {
                    HStack {
                        Text("Every")
                        Spacer()
                        Text("\(Int(settings.pollInterval))s").foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.pollInterval, in: 3...30, step: 1)
                        .onChange(of: settings.pollInterval) { _, _ in vm.restartPolling() }
                }

                Section("Glasses Display") {
                    Picker("Format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { f in Text(f.displayName).tag(f) }
                    }
                    Toggle("Show album name",    isOn: $settings.showAlbum)
                    Toggle("Show progress",      isOn: $settings.showProgress)
                    Toggle("Alert on new track", isOn: $settings.alertTrackChange)
                    LabeledContent("TCP port", value: "8094").foregroundStyle(.secondary)
                }

                Section("How to set up") {
                    Link("Create a Spotify app",
                         destination: URL(string: "https://developer.spotify.com/dashboard")!)
                    Text("1. Create an app at developer.spotify.com\n2. Copy the Client ID above\n3. Add \(SettingsStore.redirectURI) as a Redirect URI\n4. Tap Log In on the Now Playing tab")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("App",     value: "Rokid Spotify HUD")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Scopes",  value: "read-playback, modify-playback")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
