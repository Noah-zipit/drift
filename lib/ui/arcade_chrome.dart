// Shared chrome for the arcade's full-screen games: back button, pills,
// and dialog styling. One consistent look everywhere.

import 'package:flutter/material.dart';

import '../arcade/arcade_menu.dart';

/// Circular back button used on every game screen.
class ArcadeBackButton extends StatelessWidget {
  const ArcadeBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap ?? () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_rounded,
            color: Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Small floating pill, e.g. for score labels over a 3D scene.
class ArcadePill extends StatelessWidget {
  const ArcadePill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ArcadePalette.cardBorder.withValues(alpha: 0.8),
        ),
      ),
      child: child,
    );
  }
}
