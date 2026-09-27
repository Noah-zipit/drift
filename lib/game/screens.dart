// Start-menu and game-over overlays. Soft cards on a gentle scrim,
// feather-light tap sounds, and the same mute toggles as the HUD.

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'block_puzzle_game.dart';

/// Shared sound-toggle row used on the menu and game-over screens.
class _SoundToggles extends StatelessWidget {
  const _SoundToggles({required this.game});

  final BlockPuzzleGame game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: game.audio.musicEnabled,
          builder: (_, enabled, __) => IconButton(
            tooltip: enabled ? 'Mute music' : 'Unmute music',
            icon: Icon(
              enabled ? Icons.music_note : Icons.music_off,
              color: Palette.inkSoft,
            ),
            onPressed: () {
              game.audio.toggleMusic();
              game.audio.playTap();
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: game.audio.sfxEnabled,
          builder: (_, enabled, __) => IconButton(
            tooltip: enabled ? 'Mute sounds' : 'Unmute sounds',
            icon: Icon(
              enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: Palette.inkSoft,
            ),
            onPressed: () {
              game.audio.toggleSfx();
              game.audio.playTap();
            },
          ),
        ),
      ],
    );
  }
}

ButtonStyle _softButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: Palette.accent,
    foregroundColor: Palette.onAccent,
    padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    ),
    elevation: 0,
    textStyle: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),
  );
}

/// First screen. The "Begin" tap is the first user interaction, which is
/// what allows the ambient music to start (autoplay policy).
class StartMenuOverlay extends StatelessWidget {
  const StartMenuOverlay({super.key, required this.game});

  final BlockPuzzleGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Drift',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: Palette.ink,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'a juicy little puzzle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 2.2,
                color: Palette.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: game.bestNotifier,
              builder: (_, best, __) => Text(
                best > 0 ? 'best  $best' : 'no scores yet — breathe in, begin',
                style: const TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color: Palette.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: _softButtonStyle(),
              onPressed: () => game.startGame(),
              child: const Text('Begin'),
            ),
            const SizedBox(height: 28),
            _SoundToggles(game: game),
          ],
        ),
      ),
    );
  }
}

/// Shown when no tray piece fits anywhere. Score, best, restart.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final BlockPuzzleGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.scrim,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game over',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'the board is full — well played',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.1,
                  color: Palette.inkSoft,
                ),
              ),
              if (game.lastWasBest) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.boardSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'new best',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: Palette.ink,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                '${game.lastScore}',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: game.bestNotifier,
                builder: (_, best, __) => Text(
                  'best  $best',
                  style: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 1.4,
                    color: Palette.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: _softButtonStyle(),
                onPressed: () => game.startGame(),
                child: const Text('Play again'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  game.audio.playTap();
                  game.toMenu();
                },
                child: const Text(
                  'back to menu',
                  style: TextStyle(color: Palette.inkSoft),
                ),
              ),
              const SizedBox(height: 8),
              _SoundToggles(game: game),
            ],
          ),
        ),
      ),
    );
  }
}
