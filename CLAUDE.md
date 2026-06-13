# VOIDRUN — Claude Guidelines

## Godot Version
Godot 4.3 — Always use Godot 4.x API. Never use Godot 3 syntax.

## Rules
- NEVER edit .tscn files. Only create or modify .gd scripts.
- NEVER delete or rename existing files without asking.
- Before modifying an existing script, read the full file first.
- All scripts use GDScript (not C#).
- Use SOLID
- Explicit type annotations required — `:=` inference from Node/Variant methods causes parse errors (e.g. `var top: float = director.get_cam_top()`)

## Folder Structure
res://
├── scenes/
│   ├── hazards/       # hazard .tscn files
│   └── ui/            # MainMenu.tscn, DeathScreen.tscn, PauseScreen.tscn,
│                      # NickInputScreen.tscn, LeaderboardScreen.tscn,
│                      # SettingsScreen.tscn, ContinueScreen.tscn
├── scripts/
│   ├── hazards/       # hazard .gd files
│   ├── ability/       # AbilityBubble.gd, AbilityDirector.gd
│   ├── main.gd
│   ├── player.gd
│   ├── HazardDirector.gd
│   ├── virtual_joystick.gd
│   ├── SaveData.gd       # Autoload singleton
│   ├── Leaderboard.gd    # Autoload singleton
│   ├── AudioManager.gd   # Autoload singleton
│   ├── MainMenu.gd
│   ├── DeathScreen.gd
│   ├── PauseScreen.gd
│   ├── NickInputScreen.gd
│   ├── LeaderboardScreen.gd
│   ├── SettingsScreen.gd
│   └── ContinueScreen.gd
├── assets/
│   ├── sprites/
│   │   ├── hazards/bullets/
│   │   └── mobile_ui/
│   ├── fonts/         # Orbitron-VariableFont_wght.ttf
│   └── audio/
│       ├── music/     # voidrun-loop.mp3, menu.mp3
│       └── sound_effects/
└── project.godot

## Current Systems

### Player (scripts/player.gd)
- CharacterBody2D, 8-direction animated movement
- Dash: invincibility during dash, directional animations (dash_down/up/right/left at 30fps/6frames), cooldown timer, opacity feedback
- `_play_dash_anim()` — plays directional dash anim at speed_scale 1.0
- `_show_idle_pose()` — shows frame 0 of walk anim in last facing direction when standing still
- Death: `die()` sets `is_dead`, plays "dead" anim (loop disabled in code), emits `dead` signal
- Revive: `revive()` — resets dead/invincible state, plays blue flash + blink sequence (1.5s invincible then 6-frame blink)
- Ability slot: `has_ability` / `current_ability`, `receive_ability()` / `use_ability()`
- Signals: `dead`, `ability_received(type)`, `ability_used(type)`
- Near-miss flash, motion trail (`_draw()`), direction dot indicator

### Controls (MobileUI CanvasLayer)
- Virtual joystick (`scripts/virtual_joystick.gd`) — dynamic position, touch-follows
  - `disabled: bool` — setter stops active touch immediately; joystick ignores input while disabled
  - `_is_button_area()` excludes top 200px and bottom button zones
- Dash button (bottom-left) — `DashButtonContainer/DashButton` + `DashButtonContainer/CooldownLabel`
- Ability button — `SpecialButtonContainer/TouchScreenButton`, texture changes per ability type
- Pause button (top-right) — `PauseButton`

### Arena (scripts/main.gd)
- Design width: 648 units, height from background image aspect ratio
- `IMAGE_BORDER_PX = 224` — decorative border of arena.png (576×1870px)
- Scrolling camera: `Camera2D` as child of Player, `limit_top/bottom` = arena bounds
- `_play_rect: Rect2` — shared playable area (excluding side/top/bottom borders)
- Borders: StaticBody2D created in code at `_setup_arena()`
- `$HazardDirector.setup(screen_h, arena_h, cam, play_rect)`
- `$AbilityDirector.setup(screen_h, cam, play_rect)`
- Death flow: `HazardDirector.stop()` → await animation_finished → 0.5s → ContinueScreen (if internet + < 3 continues) → else DeathScreen
- Pause flow: `PauseScreen.show_pause()` / `resume()`
- Continue flow: `_show_continue_screen()` → ad_completed → `_revive_player()` / expired → `_show_death_screen()`
- `_revive_player()` — clears hazards, `HazardDirector.restart_from(survival_time)`, `AbilityDirector.start()`, `Player.revive()`
- `_continue_count: int` — max 3 continues per run

### Hazard System
- `BaseHazard` (scripts/hazards/BaseHazard.gd): base class, `active`, `activate()`, `deactivate()`
- `HazardDirector` (scripts/HazardDirector.gd): timeline-based spawning (300s designed + endless scaling), object pooling
  - `get_cam_top/bot()` — camera bounds from player position
  - `get_play_rect()` — returns `_play_rect`
  - `stop()` — stops timeline AND deactivates all active hazards in all pools
  - `restart_from(time)` — resets timeline index to 0, keeps survival_time, re-runs timeline from start
- Hazard types:
  - `ProjectileStream` — straight & diagonal bullet streams, edge warnings, player-tracking
  - `ExplosiveProjectile` / `ExplosiveBullet` — spawns at edge, flies to player Y, explodes into shards
  - `BounceStream` / `BouncingBullet` — bouncing bullets filling arena, edge warnings
  - `GroundCrack` / `TrapZone` — warn-then-lethal ground zones, self-perpetuating
  - `HomingStream` / `HomingBullet` — red-tinted bullets that steer toward player (speed 200, turn 2.0 rad/s, 6s lifetime)
  - `LaserStream` / `LaserBeam` — horizontal/vertical laser beams with warn→lethal sequence, optional sweep
	- Vertical lasers track camera center each frame (`global_position.y = (cam_min + cam_max) * 0.5`) so they always span the full visible screen height
- All hazards use `BulletWarning.gd` for edge warnings (warning.png sprite, pulse tween)
- All Area2D hazards guard `_on_body_entered` with `if not active: return`
- All bullet/hazard types add themselves to group `"clearable"` in `_ready()` — streams do NOT
- Spawn positions always clamped to `play_rect` — never in border zones
- Type inference fix required: `var top: float = director.get_cam_top()` (not `:=`)

### Bullet Sizing
- `Bullet.gd`: `set_texture(tex, scale_multiplier=1.0)` — multiplies against `_base_scale` (from scene)
- `BouncingBullet`: short=0.09, diagonal(long)=0.18 scale
- `HomingBullet`: 0.07 scale, red modulate `Color(1, 0.35, 0.35)`

### Ability System
- `AbilityBubble` (scripts/ability/AbilityBubble.gd): Area2D, spawns on map, pulses, 12s lifetime
  - `enum Type { SCREEN_CLEAR, INVINCIBILITY, TIME_SLOW }`
- `AbilityDirector` (scripts/ability/AbilityDirector.gd): spawns bubble every 15-30s
- Ability button texture swaps per type (ability-button-clear/ghost/slow/empty.png)
- `SCREEN_CLEAR` — collects non-clearable active streams, deactivates them + all clearable nodes, shows "cleared" fx, re-activates streams after 1.87s

### Audio System (scripts/AudioManager.gd) — Autoload
- SFX: `play_dash/dead/pickup/ability/select()`
- Music: `play_menu_music()` (menu.mp3), `play_music()` (voidrun-loop.mp3), `stop_music()`, `pause_music()`, `resume_music()`
  - `_music_active: bool` — `toggle_music()` only resumes if `_music_active = true` (prevents menu toggle from starting game music)
  - Both music functions swap `_music.stream` on the same AudioStreamPlayer
- Toggle: `toggle_sfx()` / `toggle_music()` — emit `sfx_toggled(muted)` / `music_toggled(muted)`
- `sfx_muted: bool`, `music_muted: bool` — public, readable by UI

### UI Scenes (scenes/ui/)
- `MainMenu.tscn` — Control root; PlayButton, LeaderboardButton, SettingsButton
  - `_ready()` calls `AudioManager.play_menu_music()` and prefetches leaderboard (all_time + weekly)
- `DeathScreen.tscn` — CanvasLayer (layer 10); all nodes are @export
  - Exports: `_time_label`, `_best_label`, `_restart_btn`, `_submit_btn`, `_menu_btn`, `_rank_label`
  - `show_result(time, is_new_best, best_time)` called from main.gd
  - Submit button: visible only on new record + no saved nick + `Leaderboard.has_internet`
  - Auto-submits (with stored nick) on new record; shows rank in `_rank_label`
  - Menu button → `MainMenu.tscn`
- `PauseScreen.tscn` — CanvasLayer (layer 10, Process Mode Always)
  - Exports: `_continue_btn`, `_sound_btn`, `_music_btn`, `_menu_btn`
  - `show_pause()` / `resume()`; menu button → `MainMenu.tscn`
- `NickInputScreen.tscn` — CanvasLayer (layer 15, above DeathScreen)
  - Exports: `_nick_input`, `_confirm_btn`, `_status_label`, `_close_btn`
  - Signals: `rank_ready(rank: int)`, `cancelled`
  - Close button emits `cancelled` and `queue_free()`; DeathScreen restores itself + submit button
- `LeaderboardScreen.tscn` — CanvasLayer (layer 12)
  - Exports: `_close_btn`, `_all_time_btn`, `_weekly_btn`, `_list_container`, `_status_label`, `_own_row`
  - Tabs: all-time / weekly; own score pinned at bottom with `modulate.a` (not `visible`) to avoid layout shift
  - Uses `Leaderboard` autoload cache; prefetch called from `MainMenu._ready()`
- `SettingsScreen.tscn` — CanvasLayer (layer 12)
  - Exports: `_close_btn`, `_sound_btn`, `_music_btn`, `_reset_btn`, `_confirm_panel`, `_confirm_yes`, `_confirm_no`
  - Reset data → `SaveData.reset()` → reload MainMenu
- `ContinueScreen.tscn` — CanvasLayer (layer 12)
  - Exports: `_countdown_label`, `_watch_ad_btn`, `_status_label`, `_close_btn`
  - Signals: `ad_completed`, `expired`
  - 5s countdown; close button emits `expired` (goes to DeathScreen)
  - Watch Ad button: mock ad (1.5s timer) → `ad_completed`; replace with real AdMob SDK later

### Save System (scripts/SaveData.gd) — Autoload
- `best_time: float`, `user_nick: String`, `device_id: String`, `pending_submission: float`
- `save_if_best(time) -> bool` — saves and returns true if new record
- `save_nick(nick)` — persists nick to disk
- `has_nick() -> bool` — true if user_nick not empty
- `reset()` — clears all data, generates new device_id, reloads save file
- `device_id` auto-generated on first run (random hex), persisted

### Leaderboard System (scripts/Leaderboard.gd) — Autoload
- Supabase REST API; table: `leaderboard` (columns: device_id UNIQUE, nick, time_seconds, created_at)
- `submit_score(nick, time_seconds)` — upsert by device_id (`?on_conflict=device_id`)
- `get_top_scores(limit, weekly)` — fetches top scores; uses in-memory cache per tab
- `get_rank(time_seconds)` — counts rows with higher score via `Content-Range` header
- `has_internet: bool` — updated by every HTTP callback; false on network error
- Signals: `score_submitted`, `scores_fetched(scores)`, `rank_fetched(rank)`, `request_failed(error)`
- Separate HTTPRequest nodes for all_time and weekly fetches (parallel-safe)

### Screen
- Portrait orientation, locked
- Start scene: MainMenu.tscn
- Font: Orbitron (assets/fonts/) — no Turkish characters, use English for button labels

### Secrets (scripts/Secrets.gd) — gitignored
- `class_name Secrets` — accessed as `Secrets.CONSTANT` from any script
- `SUPABASE_URL`, `SUPABASE_KEY` — used in Leaderboard.gd (headers built in `_ready()`, not as consts)
- `ADMOB_AD_UNIT_ID` — used in ContinueScreen.gd (`Secrets.ADMOB_AD_UNIT_ID`)
- `TEST_DEVICE_IDS: Array[String]` — used in main.gd (`MobileAds.set_request_configuration`)
- `scripts/Secrets.example.gd` and `addons/admob/android/config.example.gd` are committed as templates
- `addons/admob/android/config.gd` is also gitignored (contains AdMob App ID)

### AdMob (addons/admob/)
- Plugin: poingstudios/godot-admob-plugin
- `MobileAds.initialize()` called in `main.gd._ready()` on Android, after `set_request_configuration`
- Rewarded ad flow in `ContinueScreen.gd`: load → `_on_ad_loaded` → `show()` → `_on_ad_dismissed`
- `_rewarded_ad` and `_reward_listener` stored as instance vars to prevent GC
- `AD_UNIT_ID_TEST` const stays in ContinueScreen for editor/PC testing; real ID from Secrets on Android
- Requires **Use Gradle Build** in Android export + JDK 17

## Do Not Touch
- assets/ (managed manually)
- Any AnimationPlayer data
