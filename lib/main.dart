import 'package:flame/game.dart'; // GameWidget
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/block_puzzle_game.dart';
import 'game/hud_overlay.dart';
import 'game/screens.dart';
import 'theme/palette.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  final game = BlockPuzzleGame();

  // Pause the ambience when the app leaves the foreground; resume when it
  // returns (only if music was actually started and is enabled).
  final lifecycle = _AudioLifecycle(game);
  WidgetsBinding.instance.addObserver(lifecycle);

  runApp(
    MaterialApp(
      title: 'Drift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Palette.background,
        useMaterial3: true,
      ),
      home: _AppRoot(game: game),
    ),
  );
}

/// Shows the splash animation first, then cross-fades into the game.
class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.game});

  final BlockPuzzleGame game;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _showSplash
          ? SplashScreen(
              key: const ValueKey('splash'),
              onDone: () => setState(() => _showSplash = false),
            )
          : _GameScreen(key: const ValueKey('game'), game: widget.game),
    );
  }
}

class _GameScreen extends StatelessWidget {
  const _GameScreen({super.key, required this.game});

  final BlockPuzzleGame game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Palette.background,
        body: SafeArea(
          // One gesture detector for the whole play area. Pointer positions
          // are already in game-local coordinates because the GameWidget
          // fills this exact box. Overlay buttons (mute, Begin, Play again)
          // sit above in the GameWidget's overlay stack and keep working:
          // taps on them simply never hit a tray piece, so the game ignores
          // the accompanying pan events.
          child: GestureDetector(
            onPanStart: (details) => game.handlePanStart(
              Vector2(details.localPosition.dx, details.localPosition.dy),
            ),
            onPanUpdate: (details) => game.handlePanUpdate(
              Vector2(details.localPosition.dx, details.localPosition.dy),
            ),
            onPanEnd: (_) => game.handlePanEnd(),
            onPanCancel: () => game.handlePanEnd(),
            child: GameWidget<BlockPuzzleGame>(
              game: game,
              overlayBuilderMap: {
                'hud': (context, game) => HudOverlay(game: game),
                'start': (context, game) => StartMenuOverlay(game: game),
                'gameover': (context, game) => GameOverOverlay(game: game),
              },
              initialActiveOverlays: const ['start'],
            ),
          ),
        ),
      );
    }
  }

class _AudioLifecycle extends WidgetsBindingObserver {
  _AudioLifecycle(this.game);

  final BlockPuzzleGame game;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        game.audio.pauseMusic();
      case AppLifecycleState.resumed:
        game.audio.resumeMusic();
      case AppLifecycleState.detached:
        break;
    }
  }
}
