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
    required this.blurb,
    required this.icon,
    required this.accent,
    required this.builder,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final Color accent;
  final WidgetBuilder builder;
}

final List<_GameEntry> _games = [
  _GameEntry(
    title: "Rubik's Cube",
    blurb: 'A quiet cube to twist and unwind with. No score, no timer.',
    icon: Icons.view_in_ar_rounded,
    accent: ArcadePalette.coral,
    builder: (_) => const CubeScreen(),
  ),
  _GameEntry(
    title: 'Block Puzzle',
    blurb: 'Fit the pieces, clear rows and columns. The original Drift.',
    icon: Icons.grid_on_rounded,
    accent: const Color(0xFF7C8CFF),
    builder: (_) => const BlockPuzzleScreen(),
  ),
  _GameEntry(
    title: 'Stack',
    blurb: 'Tap to drop each layer. How high can the tower go?',
    icon: Icons.layers_rounded,
    accent: const Color(0xFF2E8B7A),
    builder: (_) => const StackScreen(),
  ),
  _GameEntry(
    title: 'Helix',
    blurb: 'Guide the ball down the spiral. Time every bounce.',
    icon: Icons.cyclone_rounded,
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 44, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DRIFT',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: ArcadePalette.foam,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'a r c a d e',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: ArcadePalette.foamDim,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverList.separated(
                itemCount: _games.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _GameCard(entry: _games[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.entry});

  final _GameEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ArcadePalette.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: entry.builder),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ArcadePalette.cardBorder, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: entry.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(entry.icon, color: entry.accent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: ArcadePalette.foam,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.blurb,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: ArcadePalette.foamDim,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ArcadePalette.foamDim,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
