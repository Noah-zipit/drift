// Helix screen: full-screen 3D spiral tower. Drag horizontally to rotate,
// press and hold to smash down. Score HUD, back button, game-over card.

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;

import '../../arcade/arcade_menu.dart';
import 'helix_controller.dart';

class HelixScreen extends StatefulWidget {
  const HelixScreen({super.key});

  @override
  State<HelixScreen> createState() => _HelixScreenState();
}

class _HelixScreenState extends State<HelixScreen> {
  final _controller = HelixController();
  bool _ready = false;
  bool _over = false;
  int _score = 0;
  int _best = 0;
  Offset? _lastPan;

  @override
  void initState() {
    super.initState();
    _controller.onScore = () {
      if (mounted) {
        setState(() {
          _score = _controller.score;
          _best = _controller.best;
        });
      }
    };
    _controller.onGameOver = () {
      if (mounted) {
        setState(() {
          _over = true;
          _score = _controller.score;
          _best = _controller.best;
        });
      }
    };
    _controller.init().then((_) {
      if (mounted) {
        setState(() {
          _ready = true;
          _best = _controller.best;
        });
      }
    });
  }

  void _restart() {
    _controller.restart();
    setState(() {
      _over = false;
      _score = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcadePalette.abyss,
      body: Stack(
        children: [
          if (_ready)
            LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) {
                    _lastPan = d.localPosition;
                    _controller.handleDown(d.localPosition, size);
                  },
                  onPanUpdate: (d) {
                    final delta = d.localPosition - (_lastPan ?? d.localPosition);
                    _lastPan = d.localPosition;
                    _controller.handleMove(d.localPosition, delta);
                  },
                  onPanEnd: (_) {
                    _lastPan = null;
                    _controller.handleUp();
                  },
                  onPanCancel: () {
                    _lastPan = null;
                    _controller.handleUp();
                  },
                  child: SceneView(
                    _controller.scene,
                    camera: _controller.camera,
                    onTick: _controller.onTick,
                  ),
                );
              },
            )
          else
            const SizedBox.expand(),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        Text(
                          '$_score',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                            color: ArcadePalette.foam,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BEST $_best',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ArcadePalette.foamDim,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 12,
                  child: _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
          if (_over)
            _GameOverCard(score: _score, best: _best, onRetry: _restart),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}

class _GameOverCard extends StatelessWidget {
  const _GameOverCard({
    required this.score,
    required this.best,
    required this.onRetry,
  });

  final int score;
  final int best;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
          decoration: BoxDecoration(
            color: ArcadePalette.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ArcadePalette.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hit the red',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ArcadePalette.foam,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: ArcadePalette.foam,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'BEST $best',
                style: const TextStyle(
                  fontSize: 13,
                  color: ArcadePalette.foamDim,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ArcadePalette.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text(
                    'Drop again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
