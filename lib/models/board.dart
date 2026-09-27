// Pure-Dart 8x8 board state. No Flutter/Flame imports.

import 'piece_shape.dart';

/// The playfield grid.
///
/// Cells hold `0` when empty, otherwise `colorIndex + 1` (so that `0`
/// unambiguously means empty regardless of the palette size).
class Board {
  static const int size = 8;

  final List<List<int>> _cells;

  Board() : _cells = List.generate(size, (_) => List.filled(size, 0));

  Board._(this._cells);

  /// Value at [row]/[col]: 0 when empty, otherwise `colorIndex + 1`.
  int cellAt(int row, int col) => _cells[row][col];

  bool inBounds(int row, int col) =>
      row >= 0 && row < size && col >= 0 && col < size;

  /// Whether [shape] can be placed with its top-left corner at [row]/[col].
  bool canPlace(PieceShape shape, int row, int col) {
    for (final cell in shape.cells) {
      final r = row + cell.y;
      final c = col + cell.x;
      if (!inBounds(r, c) || _cells[r][c] != 0) {
        return false;
      }
    }
    return true;
  }

  /// Writes [shape] into the grid. Assumes [canPlace] was checked.
  /// [colorIndex] is the palette index; it is stored as `colorIndex + 1`.
  void place(PieceShape shape, int row, int col, int colorIndex) {
    final value = colorIndex + 1;
    for (final cell in shape.cells) {
      _cells[row + cell.y][col + cell.x] = value;
    }
  }

  /// Indices of rows that are completely filled.
  List<int> fullRows() {
    final rows = <int>[];
    for (var r = 0; r < size; r++) {
      var full = true;
      for (var c = 0; c < size; c++) {
        if (_cells[r][c] == 0) {
          full = false;
          break;
        }
      }
      if (full) {
        rows.add(r);
      }
    }
    return rows;
  }

  /// Indices of columns that are completely filled.
  List<int> fullCols() {
    final cols = <int>[];
    for (var c = 0; c < size; c++) {
      var full = true;
      for (var r = 0; r < size; r++) {
        if (_cells[r][c] == 0) {
          full = false;
          break;
        }
      }
      if (full) {
        cols.add(c);
      }
    }
    return cols;
  }

  /// Every board cell covered by [rows] and/or [cols].
  /// Returned as piece-local-style [PieceCell]s where x = column, y = row.
  List<PieceCell> cellsInLines(Set<int> rows, Set<int> cols) {
    final cells = <PieceCell>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (rows.contains(r) || cols.contains(c)) {
          cells.add(PieceCell(c, r));
        }
      }
    }
    return cells;
  }

  /// Empties the given board cells.
  void clearCells(Iterable<PieceCell> cells) {
    for (final cell in cells) {
      _cells[cell.y][cell.x] = 0;
    }
  }

  /// Whether [shape] fits anywhere on the current board.
  bool fitsAnywhere(PieceShape shape) {
    for (var r = 0; r <= size - shape.height; r++) {
      for (var c = 0; c <= size - shape.width; c++) {
        if (canPlace(shape, r, c)) {
          return true;
        }
      }
    }
    return false;
  }

  int get filledCount {
    var count = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (_cells[r][c] != 0) {
          count++;
        }
      }
    }
    return count;
  }

  bool get isEmpty => filledCount == 0;

  Board copy() {
    final cells = List.generate(
      size,
      (r) => List.of(_cells[r], growable: false),
      growable: false,
    );
    return Board._(cells);
  }
}
