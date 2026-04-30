import SwiftUI

struct ContentView: View {
    @StateObject private var vm = SpotifyViewModel()

    var body: some View {
        TabView {
            NowPlayingView()
                .tabItem { Label("Now Playing", systemImage: "music.note") }
            GlassesPreviewView()
                .tabItem { Label("Glasses", systemImage: "eyeglasses") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(vm)
        .environmentObject(SettingsStore.shared)
    }
}
