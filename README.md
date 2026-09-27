# Drift

A juicy little block puzzle game built with Flutter + Flame. Fit all three
tray pieces onto the 8×8 board, complete rows and columns to pop them, and
keep going until nothing fits. Satisfying pops, glossy candy blocks.

## Design direction: juicy but smooth

Everything about this game is lively without tipping into casino chaos:

- **Palette** — deep indigo background, dark navy board, and vibrant glossy
  piece colours (bright orange, golden yellow, vivid purple, coral red, teal,
  hot pink, sky blue, lime). Each block gets a milky top gloss and a dark
  bottom shade for that candy look. White text throughout. No green-dominant
  UI.
- **Motion** — pieces glide and settle with generous `easeInOutCubic` /
  `easeOutCubic` curves. Invalid drops glide back to the tray; nothing snaps.
- **Clears** — completed lines *pop*: blocks overshoot-scale with an
  `easeOutBack` punch, then shrink away with a stagger that sweeps diagonally
  across the line (~0.02 s per step, ~0.52 s per cell), plus a modest burst
  of sparkles (3 per cell, capped at 72). No screen shake.
- **Feedback** — score popups scale in with overshoot, float up and fade;
  combo labels ("DOUBLE!", "TRIPLE!") scale in big and gold. One very light
  haptic tick on placement (`HapticFeedback.selectionClick`) and nothing else.
- **Audio** — a slow 72-second ambient pad loop (see below) plus soft SFX.
  Music and SFX have independent mute toggles, persisted across sessions.

## Controls

- **Drag** a tray piece onto the board. A white ghost shows a valid
  placement; a soft red tint shows an invalid one.
- **Release** to place, or drag away / release off-grid to return the piece.
- Pieces snap to the grid on release.
- **HUD:** big current score centred at the top, crown + best score
  top-left, music and SFX mute toggles top-right (persisted).

## Rules

- 8×8 board, three random pieces per tray round.
- 26-piece roster: single, dominoes, 3/4/5-cell lines (both orientations),
  2×2 and 3×3 squares, 2×3 rectangles, 3-cell corners, 4-cell L's, T, S, Z,
  plus-shape, and a big 5-cell L.
- Each piece gets a random vibrant colour.
- Complete **rows or columns** clear together.
- **Game over** when none of the remaining tray pieces fits anywhere on
  the board. Best score is saved locally.

## Scoring

- **Placement:** +1 per placed cell.
- **Line clear:** `10 × lines² × combo-streak` on top of the placement points.
  Clearing 2 lines at once = `10 × 4 × streak`; 3 lines = `10 × 9 × streak`.
- **Combo streak:** consecutive moves that each clear ≥ 1 line. A
  non-clearing move resets it. On-screen labels: *DOUBLE!*, *TRIPLE!*,
  *QUADRUPLE!*, then *×N!* (gold, scale-in).
- The line-clear chime rises in pitch with the streak instead of getting
  louder — the reward is felt, not shouted.

## Audio

All audio is **generated, royalty-free, synthesized from scratch** — no
samples, no copyrighted material.

| File | What |
|---|---|
| `assets/audio/ambient_loop.ogg` | 72 s seamless ambient pad (Am9 → Fmaj9 → Cmaj9 → G6/9), detuned sines, slow attack/release, 3-cycle "breathing" LFO, equal-power crossfade loop |
| `assets/audio/place.wav` | quiet soft tock on placement |
| `assets/audio/clear.wav` | warm swelling chime; pitch rises per combo via `playbackRate` |
| `assets/audio/gameover.wav` | soft low tone |
| `assets/audio/tap.wav` | feather-light UI tick |

Total: **~0.33 MB**.

### Regenerating / tweaking

```bash
python3 assets/audio_gen/gen_audio.py
```

This re-synthesizes the WAVs with Python's stdlib (`wave` + `math`), then
encodes the ambient loop to OGG with ffmpeg (`libvorbis -q:a 4`). Edit the
chord list, frequencies, envelopes, or durations in the script and re-run.
`AudioService` (`lib/audio/audio_service.dart`) references the files by name.

### Audio behaviour

- `AudioService` centralises everything: one looping `AudioPlayer` for music,
  a 4-player round-robin pool for SFX (rapid taps never cut each other off).
- Independent music / SFX volume + mute, persisted in `shared_preferences`.
- **Autoplay policy:** music starts only after the first user interaction
  (the *Begin* button → `startGame()` → `audio.startMusic()`), never before.
- Music pauses when the app backgrounds and resumes on return.
- Music ducking under the clear chime was deliberately skipped — the chime
  is quiet enough that it doesn't need it.

## Architecture

```
lib/
  main.dart            Portrait lock, MaterialApp, SafeArea, GestureDetector
                       → GameWidget + overlays ('start', 'hud', 'gameover').
                       App-lifecycle observer pauses/resumes music.
  models/              PURE DART — no Flutter/Flame imports. Unit-tested.
    piece_shape.dart   Immutable shapes (ASCII-art factory) + 26-piece roster.
    board.dart         8×8 grid: placement validity, clear detection, fitting.
    game_logic.dart    GameSession: tray, applyMove, scoring, combos, game-over.
  game/                Flame rendering + interaction (no widget rebuilds).
    block_puzzle_game.dart  Orchestrator: layout, drag input, place/clear flow,
                            overlays, haptics, best-score persistence.
    board_component.dart    Board panel, glossy cells, ghost, staggered
                            pop-clear animation.
    piece_component.dart    Draggable piece: glossy candy cells, pickup/return
                            tweens, spawn-in.
    tray_component.dart     Three slots, soft panel, hit-testing.
    effects.dart            Easing curves, ScorePopup, ComboLabel, SoftSparkle.
    hud_overlay.dart        Big centred score, crown + best (top-left),
                            mute toggles (top-right). ValueNotifiers.
    screens.dart            Start menu + game-over overlays.
  audio/
    audio_service.dart Central music/SFX manager (audioplayers).
  theme/
    palette.dart       The vibrant indigo/candy colour system.
test/
  board_test.dart      Board rules.
  game_logic_test.dart Scoring, combos, game-over.
assets/
  audio/               Generated soundscape (see above).
  audio_gen/           gen_audio.py — the synthesizer.
```

Key decisions:

- **Input at the Flutter level.** A single `GestureDetector` wraps the
  `GameWidget` and forwards pan events in game-local coordinates. No
  `TapCallbacks`/`DragCallbacks` mixins, no gesture-arena fights with Flame.
- **HUD as overlays, not Flame text.** Score/best/menus are Flutter widgets
  driven by `ValueNotifier`s — zero per-frame widget rebuilds, real buttons
  for free.
- **Model-first.** `GameSession.applyMove()` is the single source of truth
  for rules and scoring; the Flame layer only animates what the model decided.
- **Animation via tiny manual tweens** in `update(dt)` — no `flame` effects
  package, full control over the pop curves.

## Building an APK (Kaggle pipeline)

This project was written without a local Flutter SDK, so it has **not been
compiled or analysed** — first build happens in your pipeline:

1. Push this folder to a GitHub repo (source is at
   `~/workspace/block-puzzle`).
2. In your Kaggle Flutter notebook (same flow as Eviee/Sonami):
   - `git clone` the repo, `cd` into it.
   - `flutter pub get`
   - Optional but recommended: `flutter analyze`, `flutter test`
     (the model tests run headless — no device needed).
   - `flutter build apk --split-per-abi` (or `--release` universal).
3. If the `android/` stub causes Gradle complaints, delete it and run
   `flutter create --org com.example --project-name block_puzzle .` inside
   the project — the template regenerates a clean, version-matched `android/`.
   Then set your real `applicationId` (currently `com.example.blockpuzzle`).

Requirements: Flutter **3.47.5** / Dart 3.x, Android SDK from your Kaggle
image. Dependencies resolve at build time: `flame ^1.37.0`, `audioplayers
^6.0.0`, `shared_preferences ^2.3.0`.

## v2 ideas (deliberately deferred)

- Daily challenge / streaks
- More piece colour themes (e.g. "sunset", "candy", "ocean")
- Haptic-free "silent mode" preset
- Stats: total lines cleared, best combo
- iOS build + web build
- Accessibility: reduced-motion toggle, larger tray pieces
- Never: ads, IAP, leaderboards, timers, streak-pressure mechanics

## Verification status

- [x] Model logic designed for testability; unit tests written (`test/`)
- [x] Flame APIs cross-checked against current 1.x docs (only stable APIs used)
- [x] Audio synthesized and validated (`ffprobe`: 72.000 s Vorbis loop, valid WAVs)
- [x] App display name set to **Drift** (README title, start menu,
  `MaterialApp.title`, `android:label`, `pubspec.yaml` description).
  SharedPreferences keys (`driftblocks.*`) intentionally unchanged so saved
  scores/audio prefs survive the rename.
- [ ] `flutter analyze` — needs your Flutter SDK
- [ ] `flutter test` — needs your Flutter SDK
- [ ] On-device playtest — needs a real build. **Please verify visually:**
  the indigo/candy theme, the centred-score + crown HUD, and the staggered
  pop clear, since none of this revision was compiled or seen on a device.
