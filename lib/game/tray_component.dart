// The three-slot tray at the bottom of the screen. Draws its own soft
// panel and owns the [PieceComponent]s resting in it.

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/game_logic.dart';
import '../theme/palette.dart';
import 'block_puzzle_game.dart';
import 'piece_component.dart';

/// Drawn in absolute game coordinates (a plain [Component]).
class TrayComponent extends Component with HasGameReference<BlockPuzzleGame> {
  final List<PieceComponent?> slots = <PieceComponent?>[null, null, null];
  final List<Vector2> slotCentres = <Vector2>[];

  double trayTop = 0.0;
  double trayHeight = 0.0;
  double slotCellPx = 20.0;

  /// Positions the three slots across [width], vertically centred in the
  /// tray band starting at [top] with height [height].
  void layout(double width, double top, double height, double cellPx) {
    trayTop = top;
    trayHeight = height;
    slotCellPx = cellPx;
    slotCentres.clear();
    for (var i = 0; i < 3; i++) {
      slotCentres.add(
        Vector2(width * (i + 0.5) / 3.0, top + height / 2.0),
      );
    }
    // Keep resting pieces glued to their slots across resizes.
    for (var i = 0; i < slots.length; i++) {
      final piece = slots[i];
      if (piece != null && !piece.dragging && i < slotCentres.length) {
        piece.homePos.setFrom(slotCentres[i]);
        piece.position.setFrom(slotCentres[i]);
      }
    }
  }

  /// Creates piece visuals for the given tray state with a soft stagger.
  void spawnPieces(List<TrayPiece?> pieces) {
    clear();
    for (var i = 0; i < pieces.length && i < 3; i++) {
      final trayPiece = pieces[i];
      if (trayPiece == null || i >= slotCentres.length) {
        continue;
      }
      final component = PieceComponent(
        shape: trayPiece.shape,
        colorIndex: trayPiece.colorIndex,
        trayIndex: i,
        home: slotCentres[i],
        homeCell: slotCellPx,
      )..spawn(delay: i * 0.09);
      slots[i] = component;
      gameRef.add(component);
    }
  }

  /// Topmost resting piece whose bounds contain [pos], if any.
  PieceComponent? pieceAt(Vector2 pos) {
    for (var i = slots.length - 1; i >= 0; i--) {
      final piece = slots[i];
      if (piece == null || piece.isSpawning) {
        continue;
      }
      final halfW = piece.size.x / 2 + 14;
      final halfH = piece.size.y / 2 + 14;
      if ((pos.x - piece.position.x).abs() <= halfW &&
          (pos.y - piece.position.y).abs() <= halfH) {
        return piece;
      }
    }
    return null;
  }

  void removePiece(PieceComponent piece) {
    if (piece.trayIndex >= 0 && piece.trayIndex < slots.length) {
      slots[piece.trayIndex] = null;
    }
    piece.removeFromParent();
  }

  void clear() {
    for (var i = 0; i < slots.length; i++) {
      slots[i]?.removeFromParent();
      slots[i] = null;
    }
  }

  @override
  void render(Canvas canvas) {
    if (slotCentres.isEmpty) {
      return;
    }
    final width = gameRef.size.x;
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(16, trayTop + 8, width - 32, trayHeight - 16),
      const Radius.circular(28),
    );
    canvas.drawRRect(panel, Paint()..color = Palette.traySurface);
  }
}
