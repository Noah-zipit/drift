// Pure-Dart piece shape definitions. No Flutter/Flame imports.

import 'dart:math';

/// A single filled cell of a piece in piece-local coordinates.
/// [x] is the column, [y] is the row; (0, 0) is the top-left of the
/// piece's bounding box.
class PieceCell {
  const PieceCell(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is PieceCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PieceCell($x, $y)';
}

/// An immutable polyomino shape used by the game.
class PieceShape {
  final String name;
  final List<PieceCell> cells;
  final int width; // bounding-box width in cells
  final int height; // bounding-box height in cells

  const PieceShape._(this.name, this.cells, this.width, this.height);

  int get cellCount => cells.length;

  /// Builds a shape from ASCII rows, where '#' is a filled cell.
  /// Rows may have different lengths; shorter rows are treated as empty.
  factory PieceShape.fromRows(String name, List<String> rows) {
    final cells = <PieceCell>[];
    var width = 0;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        if (row[x] == '#') {
          cells.add(PieceCell(x, y));
        }
      }
      width = max(width, row.length);
    }
    return PieceShape._(name, List.unmodifiable(cells), width, rows.length);
  }

  @override
  String toString() => 'PieceShape($name, ${cells.length} cells)';
}

/// The full roster of shapes the tray can draw from.
class PieceShapes {
  static final List<PieceShape> all = <PieceShape>[
    PieceShape.fromRows('dot', ['#']),
    PieceShape.fromRows('domino_h', ['##']),
    PieceShape.fromRows('domino_v', ['#', '#']),
    PieceShape.fromRows('trio_h', ['###']),
    PieceShape.fromRows('trio_v', ['#', '#', '#']),
    PieceShape.fromRows('line4_h', ['####']),
    PieceShape.fromRows('line4_v', ['#', '#', '#', '#']),
    PieceShape.fromRows('line5_h', ['#####']),
    PieceShape.fromRows('line5_v', ['#', '#', '#', '#', '#']),
    PieceShape.fromRows('square2', ['##', '##']),
    PieceShape.fromRows('square3', ['###', '###', '###']),
    PieceShape.fromRows('corner_a', ['##', '#.']),
    PieceShape.fromRows('corner_b', ['##', '.#']),
    PieceShape.fromRows('corner_c', ['#.', '##']),
    PieceShape.fromRows('corner_d', ['.#', '##']),
    PieceShape.fromRows('ell_a', ['#..', '###']),
    PieceShape.fromRows('ell_b', ['..#', '###']),
    PieceShape.fromRows('ell_c', ['#.', '#.', '##']),
    PieceShape.fromRows('ell_d', ['.#', '.#', '##']),
    PieceShape.fromRows('tee', ['###', '.#.']),
    PieceShape.fromRows('ess', ['.##', '##.']),
    PieceShape.fromRows('zed', ['##.', '.##']),
    PieceShape.fromRows('rect_h', ['###', '###']),
    PieceShape.fromRows('rect_v', ['##', '##', '##']),
    PieceShape.fromRows('plus', ['.#.', '###', '.#.']),
    PieceShape.fromRows('big_ell', ['#..', '#..', '###']),
  ];

  static PieceShape byName(String name) =>
      all.firstWhere((s) => s.name == name);

  static PieceShape random(Random rng) => all[rng.nextInt(all.length)];
}
