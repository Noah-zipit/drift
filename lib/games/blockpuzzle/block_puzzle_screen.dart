// Block Puzzle as an arcade game route. Wraps the original Drift game
// untouched, adding only a back button to return to the arcade menu.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/block_puzzle_game.dart';
import '../../game/hud_overlay.dart';
import '../../game/screens.dart';
import '../../theme/palette.dart';
import '../../ui/arcade_chrome.dart';

class BlockPuzzleScreen extends StatefulWidget {
  const BlockPuzzleScreen({super.key});

  @override
  State<BlockPuzzleScreen> createState() => _BlockPuzzleScreenState();
}

class _BlockPuzzleScreenState extends State<BlockPuzzleScreen>
    with WidgetsBindingObserver {
  late final BlockPuzzleGame _game;

  @override
  void initState() {
    super.initState();
    _game = BlockPuzzleGame();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _game.audio.pauseMusic();
      case AppLifecycleState.resumed:
        _game.audio.resumeMusic();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      body: SafeArea(
        child: GestureDetector(
          onPanStart: (details) => _game.handlePanStart(
            Vector2(details.localPosition.dx, details.localPosition.dy),
          ),
          onPanUpdate: (details) => _game.handlePanUpdate(
            Vector2(details.localPosition.dx, details.localPosition.dy),
          ),
          onPanEnd: (_) => _game.handlePanEnd(),
          onPanCancel: () => _game.handlePanEnd(),
          child: Stack(
            children: [
              GameWidget<BlockPuzzleGame>(
                game: _game,
                overlayBuilderMap: {
                  'hud': (context, game) => HudOverlay(game: game),
                  'start': (context, game) => StartMenuOverlay(game: game),
                  'gameover': (context, game) => GameOverOverlay(game: game),
                },
                initialActiveOverlays: const ['start'],
              ),
              Positioned(
                top: 64,
                left: 12,
                child: const ArcadeBackButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
