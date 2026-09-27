// In-game HUD overlay: big centred score, crown + best top-left,
// music/SFX mute toggles top-right.
//
// The score texts listen to the game's ValueNotifiers, so nothing rebuilds
// per frame. Everything except the mute buttons is pointer-transparent,
// so drag gestures pass straight through to the game below.

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'block_puzzle_game.dart';

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final BlockPuzzleGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Crown + best score, top-left.
        Positioned(
          top: 16,
          left: 18,
          child: IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Palette.crown,
                  size: 26,
                ),
                const SizedBox(width: 6),
                ValueListenableBuilder<int>(
                  valueListenable: game.bestNotifier,
                  builder: (_, best, __) => Text(
                    '$best',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Palette.crown,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Big current score, centred at the top.
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: game.scoreNotifier,
              builder: (_, score, __) => Text(
                '$score',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Palette.ink,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
        // Mute toggles, top-right.
        Positioned(
          top: 12,
          right: 10,
          child: Row(
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
          ),
        ),
      ],
    );
  }
}
