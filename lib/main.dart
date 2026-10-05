// Drift Arcade — entry point. Splash first, then the game picker hub.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arcade/arcade_menu.dart';
import 'theme/palette.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    MaterialApp(
      title: 'Drift Arcade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Palette.background,
        useMaterial3: true,
      ),
      home: const _AppRoot(),
    ),
  );
}

/// Shows the splash animation first, then cross-fades into the arcade menu.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

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
          : const ArcadeMenu(key: ValueKey('arcade')),
    );
  }
}
