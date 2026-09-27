// Renders the 8x8 board: dark navy panel, glossy candy cells, ghost
// preview, and the staggered pop animation used for line clears.

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/piece_shape.dart';
import '../theme/palette.dart';
import 'effects.dart';

class _Ghost {
  _Ghost(this.shape, this.row, this.col, this.valid);

  final PieceShape shape;
  final int row;
  final int col;
  final bool valid;
}

/// Drawn in absolute game coordinates (a plain [Component]).
class BoardComponent extends Component {
  static const double panelPadding = 10.0;

  /// Seconds per diagonal step of the clear-pop sweep.
  static const double popStagger = 0.02;

  /// Seconds a single cell takes to pop and shrink away.
  static const double popDuration = 0.52;

  Vector2 origin = Vector2.zero(); // top-left of the cell grid
  double cell = 40.0;

  /// -1 = empty, otherwise the palette colour index.
  final List<List<int>> colours =
      List.generate(Board.size, (_) => List.filled(Board.size, -1));

  /// Placement settle animation, 0..1 (1 = settled).
  final List<List<double>> appear =
      List.generate(Board.size, (_) => List.filled(Board.size, 1.0));

  /// Clear pop animation: elapsed seconds since the pop started,
  /// -1 = inactive.
  final List<List<double>> dissolve =
      List.generate(Board.size, (_) => List.filled(Board.size, -1.0));

  /// Per-cell stagger delay (seconds) so the pop sweeps across the line.
  final List<List<double>> clearDelay =
      List.generate(Board.size, (_) => List.filled(Board.size, 0.0));

  _Ghost? ghost;

  void layout(Vector2 boardOrigin, double cellSize) {
    origin = boardOrigin.clone();
    cell = cellSize;
  }

  void reset() {
    for (var r = 0; r < Board.size; r++) {
      for (var c = 0; c < Board.size; c++) {
        colours[r][c] = -1;
        appear[r][c] = 1.0;
        dissolve[r][c] = -1.0;
        clearDelay[r][c] = 0.0;
      }
    }
    ghost = null;
  }

  /// Marks freshly placed cells; they settle in gently via [update].
  void placeCells(PieceShape shape, int row, int col, int colorIndex) {
    for (final cell in shape.cells) {
      final r = row + cell.y;
      final c = col + cell.x;
      colours[r][c] = colorIndex;
      appear[r][c] = 0.0;
      dissolve[r][c] = -1.0;
      clearDelay[r][c] = 0.0;
    }
  }

  /// Starts the pop on the given board cells. The pop sweeps diagonally
  /// (top-left to bottom-right) via a small per-cell delay.
  void dissolveCells(List<PieceCell> cells) {
    for (final cell in cells) {
      final r = cell.y;
      final c = cell.x;
      if (colours[r][c] >= 0) {
        dissolve[r][c] = 0.0;
        clearDelay[r][c] = (r + c) * popStagger;
      }
    }
  }

  /// Centre of a board cell in game coordinates (for sparkles).
  Vector2 cellCentre(int row, int col) => Vector2(
        origin.x + col * cell + cell / 2,
        origin.y + row * cell + cell / 2,
      );

  void setGhost(PieceShape shape, int row, int col, bool valid) {
    ghost = _Ghost(shape, row, col, valid);
  }

  void clearGhost() {
    ghost = null;
  }

  @override
  void update(double dt) {
    for (var r = 0; r < Board.size; r++) {
      for (var c = 0; c < Board.size; c++) {
        if (appear[r][c] < 1.0) {
          appear[r][c] = clamp01(appear[r][c] + dt / 0.28);
        }
        if (dissolve[r][c] >= 0.0) {
          final t = dissolve[r][c] + dt;
          final k = clamp01((t - clearDelay[r][c]) / popDuration);
          if (k >= 1.0) {
            dissolve[r][c] = -1.0;
            clearDelay[r][c] = 0.0;
            colours[r][c] = -1;
            appear[r][c] = 1.0;
          } else {
            dissolve[r][c] = t;
          }
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final gap = cell * 0.07;

    // Dark navy panel.
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        origin.x - panelPadding,
        origin.y - panelPadding,
        cell * Board.size + panelPadding * 2,
        cell * Board.size + panelPadding * 2,
      ),
      Radius.circular(cell * 0.42),
    );
    canvas.drawRRect(panel, Paint()..color = Palette.boardSurface);

    for (var r = 0; r < Board.size; r++) {
      for (var c = 0; c < Board.size; c++) {
        final x = origin.x + c * cell;
        final y = origin.y + r * cell;
        final colourIndex = colours[r][c];
        if (colourIndex < 0) {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x + gap, y + gap, cell - gap * 2, cell - gap * 2),
            Radius.circular(cell * 0.2),
          );
          canvas.drawRRect(rect, Paint()..color = Palette.emptyCell);
          continue;
        }

        var alpha = easeOutCubic(appear[r][c]);
        var scale = 0.72 + 0.28 * easeOutCubic(appear[r][c]);
        final d = dissolve[r][c];
        if (d >= 0.0) {
          final k = clamp01((d - clearDelay[r][c]) / popDuration);
          if (k <= 0.0) {
            // Still inside the stagger delay: draw settled.
          } else if (k < 0.32) {
            // Phase 1: quick overshoot pop.
            scale *= 1.0 + 0.22 * easeOutBack(k / 0.32);
          } else {
            // Phase 2: shrink away and fade.
            final u = (k - 0.32) / 0.68;
            scale *= 1.22 * (1.0 - easeInCubic(u));
            alpha *= 1.0 - easeOutCubic(u);
          }
        }
        if (alpha <= 0.01 || scale <= 0.01) {
          continue;
        }

        final base = Palette.pieces[colourIndex % Palette.pieces.length];
        final cx = x + cell / 2;
        final cy = y + cell / 2;
        final half = (cell - gap * 2) * scale / 2;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: half * 2,
            height: half * 2,
          ),
          Radius.circular(cell * 0.2 * scale),
        );
        canvas.drawRRect(rect, Paint()..color = base.withValues(alpha: alpha));

        // Glossy top sheen.
        final gloss = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy - half * 0.3),
            width: half * 2 * 0.9,
            height: half * 2 * 0.44,
          ),
          Radius.circular(cell * 0.14 * scale),
        );
        canvas.drawRRect(
          gloss,
          Paint()..color = Palette.highlight(base).withValues(alpha: alpha * 0.8),
        );

        // Bottom shade for glossy depth.
        final shadeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy + half * 0.38),
            width: half * 2 * 0.9,
            height: half * 2 * 0.24,
          ),
          Radius.circular(cell * 0.1 * scale),
        );
        canvas.drawRRect(
          shadeRect,
          Paint()..color = Palette.shade(base).withValues(alpha: alpha * 0.55),
        );
      }
    }

    // Ghost preview.
    final g = ghost;
    if (g != null) {
      final tint = g.valid ? Palette.ghostValid : Palette.ghostInvalid;
      final ghostAlpha = g.valid ? 0.38 : 0.30;
      for (final pc in g.shape.cells) {
        final r = g.row + pc.y;
        final c = g.col + pc.x;
        if (r < 0 || r >= Board.size || c < 0 || c >= Board.size) {
          continue;
        }
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.x + c * cell + gap,
            origin.y + r * cell + gap,
            cell - gap * 2,
            cell - gap * 2,
          ),
          Radius.circular(cell * 0.2),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = tint.withValues(alpha: ghostAlpha),
        );
      }
    }
  }
}
