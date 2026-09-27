// A draggable tray piece. Renders its shape as glossy rounded candy cells
// and glides between the tray and the pointer with gentle tweens.

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/piece_shape.dart';
import '../theme/palette.dart';
import 'block_puzzle_game.dart';
import 'effects.dart';

class PieceComponent extends PositionComponent
    with HasGameReference<BlockPuzzleGame> {
  PieceComponent({
    required this.shape,
    required this.colorIndex,
    required this.trayIndex,
    required Vector2 home,
    required double homeCell,
  })  : homePos = home.clone(),
        homeCellPx = homeCell,
        cellPx = homeCell {
    anchor = Anchor.center;
    position = home.clone();
    priority = 20;
    _syncSize();
  }

  final PieceShape shape;
  final int colorIndex;
  final int trayIndex;

  /// Where this piece rests in the tray.
  final Vector2 homePos;

  /// Rendered cell size while resting in the tray.
  final double homeCellPx;

  /// Current rendered cell size (tweens between tray and full-board size).
  double cellPx;

  bool dragging = false;

  // Spawn-in animation.
  double _spawnT = 1.0;
  double _spawnDelay = 0.0;

  // Generic position/cell-size tween (pickup, return-to-tray).
  double _animT = 1.0;
  double _animDur = 0.001;
  final Vector2 _animFromPos = Vector2.zero();
  final Vector2 _animToPos = Vector2.zero();
  double _animFromCell = 0.0;
  double _animToCell = 0.0;

  void _syncSize() {
    size.setValues(shape.width * cellPx, shape.height * cellPx);
  }

  /// Gentle fade/scale entrance with a per-slot stagger [delay].
  void spawn({double delay = 0.0}) {
    _spawnT = 0.0;
    _spawnDelay = delay;
    cellPx = homeCellPx;
    _syncSize();
  }

  bool get isSpawning => _spawnDelay > 0 || _spawnT < 1.0;

  /// Lifted by the pointer: glides to full board cell size.
  void pickUp() {
    dragging = true;
    priority = 40;
    _startAnim(position.clone(), game.cell, 0.18);
  }

  /// Follows the pointer exactly; the glide comes from the pickup/return
  /// tweens and the eased ghost, not from lagging behind the finger.
  void dragTo(Vector2 pointer) {
    _animT = 1.0;
    position.setFrom(pointer);
  }

  /// Glides back to its tray slot after an invalid drop.
  void returnToTray() {
    dragging = false;
    priority = 20;
    _startAnim(homePos.clone(), homeCellPx, 0.35);
  }

  /// Called when the piece is placed: the board takes over the visuals.
  void placed() {
    dragging = false;
  }

  void _startAnim(Vector2 toPos, double toCell, double duration) {
    _animFromPos.setFrom(position);
    _animToPos.setFrom(toPos);
    _animFromCell = cellPx;
    _animToCell = toCell;
    _animDur = duration;
    _animT = 0.0;
  }

  @override
  void update(double dt) {
    if (_spawnDelay > 0) {
      _spawnDelay -= dt;
    } else if (_spawnT < 1.0) {
      _spawnT = clamp01(_spawnT + dt / 0.45);
    }
    if (_animT < 1.0) {
      _animT = clamp01(_animT + dt / _animDur);
      final e = easeInOutCubic(_animT);
      position.setValues(
        _animFromPos.x + (_animToPos.x - _animFromPos.x) * e,
        _animFromPos.y + (_animToPos.y - _animFromPos.y) * e,
      );
      cellPx = _animFromCell + (_animToCell - _animFromCell) * e;
      _syncSize();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_spawnDelay > 0) {
      return;
    }
    final alpha = easeOutCubic(_spawnT);
    if (alpha <= 0.01) {
      return;
    }
    final base = Palette.pieces[colorIndex % Palette.pieces.length];
    final r = cellPx;
    final gap = r * 0.07;

    // A whisper of a shadow while dragging, so the piece feels lifted.
    if (dragging) {
      final shadowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -size.x / 2 + 2,
          -size.y / 2 + 8,
          size.x - 4,
          size.y - 4,
        ),
        Radius.circular(r * 0.24),
      );
      canvas.drawRRect(
        shadowRect,
        Paint()
          ..color = const Color(0x14000000).withValues(alpha: 0.08 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    final fill = Paint()..color = base.withValues(alpha: alpha);
    final light = Paint()
      ..color = Palette.highlight(base).withValues(alpha: alpha * 0.8);
    final dark = Paint()
      ..color = Palette.shade(base).withValues(alpha: alpha * 0.55);

    for (final cell in shape.cells) {
      // Local coords: anchor is center, so top-left is -size/2.
      final lx = -size.x / 2 + cell.x * r;
      final ly = -size.y / 2 + cell.y * r;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(lx + gap, ly + gap, r - gap * 2, r - gap * 2),
        Radius.circular(r * 0.22),
      );
      canvas.drawRRect(rect, fill);

      // Glossy top sheen.
      final h = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          lx + gap + (r - gap * 2) * 0.05,
          ly + gap,
          (r - gap * 2) * 0.9,
          (r - gap * 2) * 0.44,
        ),
        Radius.circular(r * 0.14),
      );
      canvas.drawRRect(h, light);

      // Bottom shade for glossy depth.
      final s = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          lx + gap + (r - gap * 2) * 0.05,
          ly + gap + (r - gap * 2) * 0.76,
          (r - gap * 2) * 0.9,
          (r - gap * 2) * 0.24,
        ),
        Radius.circular(r * 0.1),
      );
      canvas.drawRRect(s, dark);
    }
  }
}
