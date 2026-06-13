# VOIDRUN

A mobile bullet-hell survival game built with Godot 4.3.

Dodge an endless wave of hazards for as long as possible. Compete on the global leaderboard.

## Tech Stack

- **Engine**: Godot 4.3 (GDScript)
- **Backend**: Supabase (leaderboard)
- **Ads**: Google AdMob via [poing-godot-admob](https://github.com/poingstudios/godot-admob-plugin)
- **Platform**: Android (portrait)

## Setup

### 1. Secrets

Copy the example file and fill in your own keys:

```
scripts/Secrets.example.gd  →  scripts/Secrets.gd
addons/admob/android/config.example.gd  →  addons/admob/android/config.gd
```

`Secrets.gd` requires:
- `SUPABASE_URL` — your Supabase project URL
- `SUPABASE_KEY` — your Supabase anon key
- `ADMOB_AD_UNIT_ID` — your AdMob rewarded ad unit ID
- `TEST_DEVICE_IDS` — device hashes for test ads (from logcat)

### 2. AdMob Plugin

The AdMob plugin (`addons/admob/`) is included. Android binaries are in `addons/admob/android/bin/`.

### 3. Android Export

- Enable **Use Gradle Build** in the Android export preset
- Requires JDK 17 (Gradle 8.x does not support Java 21+)
- Set JDK path: Editor → Editor Settings → Export → Android → Java SDK Path

## Build

Export via **Project → Export → Android → Export Project** as `.aab` for Play Store.
