// Drift Arcade — the game picker hub. Each entry launches a full-screen
// game route; the system back button/gesture returns here.

import 'package:flutter/material.dart';

import '../games/blockpuzzle/block_puzzle_screen.dart';
import '../games/cube/cube_screen.dart';
import '../games/helix/helix_screen.dart';
import '../games/stack/stack_screen.dart';

/// Abyss palette shared by the arcade hub and the 3D games.
class ArcadePalette {
  static const abyss = Color(0xFF04262C);
  static const deep = Color(0xFF0A3540);
  static const coral = Color(0xFFFF6F61);
  static const foam = Color(0xFFE9F2ED);
  static const foamDim = Color(0xFF9DB8B2);
  static const card = Color(0xFF0B2E35);
  static const cardBorder = Color(0xFF14454F);
}

class _GameEntry {
  const _GameEntry({
    required this.title,
    required this.tag,
    required this.art,
    required this.accent,
    required this.builder,
  });

  final String title;
  final String tag;
  final String art;
  final Color accent;
  final WidgetBuilder builder;
}

final List<_GameEntry> _games = [
  _GameEntry(
    title: "Rubik's Cube",
    tag: 'No score. Just unwind.',
    art: 'assets/icon/game_cube.png',
    accent: ArcadePalette.coral,
    builder: (_) => const CubeScreen(),
  ),
  _GameEntry(
    title: 'Block Puzzle',
    tag: 'The original Drift.',
    art: 'assets/icon/game_blocks.png',
    accent: const Color(0xFF7C8CFF),
    builder: (_) => const BlockPuzzleScreen(),
  ),
  _GameEntry(
    title: 'Stack',
    tag: 'How high can you go?',
    art: 'assets/icon/game_stack.png',
    accent: const Color(0xFF2E8B7A),
    builder: (_) => const StackScreen(),
  ),
  _GameEntry(
    title: 'Helix',
    tag: 'Time every bounce.',
    art: 'assets/icon/game_helix.png',
    accent: const Color(0xFFC9A227),
    builder: (_) => const HelixScreen(),
  ),
];

class ArcadeMenu extends StatelessWidget {
  const ArcadeMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcadePalette.abyss,
      body: Stack(
        children: [
          // Faint depth glow behind the header.
          const Positioned(
            top: -120,
            left: 0,
            right: 0,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.15, 0.0),
                    radius: 0.9,
                    colors: [
                      Color(0xFF0E3A44),
                      Color(0x000A3540),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.74,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _GameTile(entry: _games[i]),
                      childCount: _games.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 28, top: 4),
                    child: Center(
                      child: Text(
                        'DRIFT ARCADE · v1.0',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3,
                          color: Color(0xFF5E7A75),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: ArcadePalette.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: ArcadePalette.coral.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: ArcadePalette.coral,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '4 GAMES READY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: ArcadePalette.foam,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Drift',
            style: TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: ArcadePalette.foam,
              letterSpacing: 1,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ARCADE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ArcadePalette.coral,
              letterSpacing: 12,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Four games. Zero noise — pick one and play.',
            style: TextStyle(
              fontSize: 14,
              color: ArcadePalette.foamDim,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.entry});

  final _GameEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: entry.builder),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ArcadePalette.cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: entry.accent.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    entry.art,
                    fit: BoxFit.cover,
                  ),
                ),
                // Bottom scrim for legible text.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x0004262C),
                          Color(0x6604262C),
                          Color(0xF204262C),
                        ],
                        stops: [0.35, 0.62, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: entry.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: entry.accent.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ArcadePalette.foam,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ArcadePalette.foamDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
