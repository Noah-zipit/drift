// Pure-Dart game session: tray management, move application, scoring,
// combo streaks and game-over detection. No Flutter/Flame imports.

import 'dart:math';

import 'board.dart';
import 'piece_shape.dart';

/// A piece waiting in the tray: its shape plus a palette colour index.
class TrayPiece {
  const TrayPiece(this.shape, this.colorIndex);

  final PieceShape shape;
  final int colorIndex;
}

/// The outcome of a single applied move.
class MoveResult {
  const MoveResult({
    required this.scoreGained,
    required this.linesCleared,
    required this.comboStreak,
    required this.clearedCells,
    required this.clearedColors,
    required this.trayEmpty,
  });

  /// Total points awarded for this move (placement + clear bonus).
  final int scoreGained;

  /// Number of rows+columns cleared by this move (0 when none).
  final int linesCleared;

  /// Current consecutive-clear streak (0 when this move cleared nothing).
  final int comboStreak;

  /// Board cells that were cleared (empty before [applyMove] returns).
  final List<PieceCell> clearedCells;

  /// Palette colour index of each entry in [clearedCells] (for effects).
  final List<int> clearedColors;

  /// Whether the tray is empty after this move (caller should refill).
  final bool trayEmpty;
}

/// Owns the board, the score, the tray and the rules that bind them.
class GameSession {
  GameSession({Random? rng, this.colorCount = 8})
      : _rng = rng ?? Random();

  final Random _rng;

  /// Number of palette colours pieces may draw from.
  final int colorCount;

  final Board board = Board();

  int score = 0;

  /// Consecutive moves that each cleared at least one line.
  int comboStreak = 0;

  int movesPlayed = 0;

  /// Three tray slots; a slot is `null` once its piece has been placed.
  final List<TrayPiece?> tray = <TrayPiece?>[null, null, null];

  /// Deals three fresh random pieces into the tray.
  void refillTray() {
    for (var i = 0; i < tray.length; i++) {
      tray[i] = TrayPiece(
        PieceShapes.random(_rng),
        _rng.nextInt(colorCount),
      );
    }
  }

  bool get trayEmpty => tray.every((piece) => piece == null);

  /// True when none of the remaining tray pieces fits anywhere.
  /// Callers should refill an empty tray before asking.
  bool get isGameOver {
    for (final piece in tray) {
      if (piece != null && board.fitsAnywhere(piece.shape)) {
        return false;
      }
    }
    return true;
  }

  /// Applies a legal move: places the tray piece, scores it, clears any
  /// completed lines and updates the combo streak.
  ///
  /// The caller is responsible for checking placement validity first
  /// (via [Board.canPlace]) and for refilling the tray / checking
  /// [isGameOver] afterwards.
  MoveResult applyMove(int trayIndex, int row, int col) {
    final piece = tray[trayIndex];
    if (piece == null) {
      throw StateError('Tray slot $trayIndex is empty.');
    }
    if (!board.canPlace(piece.shape, row, col)) {
      throw StateError('Illegal placement at ($row, $col).');
    }

    board.place(piece.shape, row, col, piece.colorIndex);
    tray[trayIndex] = null;
    movesPlayed++;

    var gained = piece.shape.cellCount;

    final rows = board.fullRows().toSet();
    final cols = board.fullCols().toSet();
    final clearedCells = board.cellsInLines(rows, cols);
    final clearedColors = <int>[
      for (final cell in clearedCells) board.cellAt(cell.y, cell.x) - 1,
    ];
    final lines = rows.length + cols.length;

    var streak = 0;
    if (lines > 0) {
      comboStreak += 1;
      streak = comboStreak;
      gained += 10 * lines * lines * streak;
      board.clearCells(clearedCells);
    } else {
      comboStreak = 0;
    }

    score += gained;

    return MoveResult(
      scoreGained: gained,
      linesCleared: lines,
      comboStreak: streak,
      clearedCells: clearedCells,
      clearedColors: clearedColors,
      trayEmpty: trayEmpty,
    );
  }

  /// Quiet, elegant label for a combo streak of 2+.
  static String comboLabel(int streak) {
    switch (streak) {
      case 2:
        return 'Double clear';
      case 3:
        return 'Triple clear';
      case 4:
        return 'Quadruple clear';
      default:
        return '\u00d7$streak clear';
    }
  }
}
