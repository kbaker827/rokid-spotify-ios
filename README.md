# Rokid Spotify HUD


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that connects to the **Spotify Web API** and streams now-playing track info to **Rokid AR glasses** via Bluetooth/RokidSDK.

```
Spotify Web API ──HTTPS──▶ iPhone (RokidSpotify) ──Bluetooth/RokidSDK──▶ Rokid Glasses
```

## What's displayed on the glasses

```json
{"type":"playback","text":"▶ Blinding Lights — The Weeknd  |  2:14/3:20","playing":true}
{"type":"alert","text":"♪ Save Your Tears — The Weeknd"}
{"type":"playback","text":"⏸ Paused","playing":false}
```

## Display formats

| Format | Example |
|--------|---------|
| **Compact** | `▶ Blinding Lights — The Weeknd  \|  2:14/3:20` |
| **Detailed** | Track / Artist / Album / Progress % on separate lines |
| **Minimal** | `▶ Blinding Lights` |

## Controls

Full playback control from the Now Playing tab:

| Button | Action |
|--------|--------|
| ▶ / ⏸ | Play / Pause |
| ⏮ | Previous track |
| ⏭ | Next track |
| 🔀 | Toggle shuffle |
| 🔁 | Cycle repeat (off → context → track) |

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into the glasses Swift file:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Setup

### 1. Create a Spotify app

1. Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
2. Create a new app (any name)
3. Add **`rokidspotify://callback`** as a Redirect URI
4. Copy the **Client ID**

### 2. Configure the iOS app

1. Open `RokidSpotify.xcworkspace` in Xcode 15+ (after running `pod install`) 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. In **Settings**: paste your Client ID.
5. Go to **Now Playing** and tap **Log in with Spotify**.
6. Authorize in the browser — the app handles the PKCE callback automatically.

### 3. Connect glasses

7. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*
8. Play any track in Spotify — it appears on the glasses within the poll interval.

## Auth flow (PKCE)

No client secret needed — uses the Authorization Code with PKCE flow:

```
App → auth URL with code_challenge (SHA256 of random verifier)
     → accounts.spotify.com login page (ASWebAuthenticationSession)
     → rokidspotify://callback?code=…
     → POST /api/token  { code, code_verifier }
     → access_token + refresh_token stored
     → auto-refresh when expired
```

## Required Spotify scopes

| Scope | Purpose |
|-------|---------|
| `user-read-playback-state` | Read current track & device |
| `user-modify-playback-state` | Play, pause, skip, shuffle, repeat |
| `user-read-currently-playing` | Now Playing endpoint |
| `user-read-recently-played` | Recently Played list |

## Requirements

- iOS 17.0+
- Xcode 15+
- Spotify account (free or Premium)
- Spotify Premium required for playback control commands
- Rokid AI glasses (paired via Bluetooth — no Wi-Fi needed) (optional)
