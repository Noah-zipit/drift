import 'package:flutter_test/flutter_test.dart';

import 'package:block_puzzle/models/board.dart';
import 'package:block_puzzle/models/piece_shape.dart';

void main() {
  group('PieceShape.fromRows', () {
    test('normalises cells and bounding box', () {
      final shape = PieceShape.fromRows('ell_a', ['#..', '###']);
      expect(shape.width, 3);
      expect(shape.height, 2);
      expect(shape.cellCount, 4);
      expect(
        shape.cells,
        containsAll(const [
          PieceCell(0, 0),
          PieceCell(0, 1),
          PieceCell(1, 1),
          PieceCell(2, 1),
        ]),
      );
    });

    test('roster has the expected shapes', () {
      final names = PieceShapes.all.map((s) => s.name).toSet();
      for (final name in [
        'dot',
        'domino_h',
        'domino_v',
        'trio_h',
        'line4_h',
        'line5_h',
        'square2',
        'square3',
        'rect_h',
        'tee',
        'ess',
        'zed',
        'plus',
      ]) {
        expect(names, contains(name));
      }
      // Every roster shape has at least one cell and a sane bounding box.
      for (final shape in PieceShapes.all) {
        expect(shape.cellCount, greaterThan(0));
        expect(shape.width, greaterThan(0));
        expect(shape.height, greaterThan(0));
      }
    });
  });

  group('Board', () {
    test('canPlace respects bounds and occupancy', () {
      final board = Board();
      final square = PieceShapes.byName('square2');
      expect(board.canPlace(square, 0, 0), isTrue);
      expect(board.canPlace(square, 6, 6), isTrue);
      expect(board.canPlace(square, 7, 7), isFalse); // overflows bottom-right
      expect(board.canPlace(square, -1, 0), isFalse);
      expect(board.canPlace(square, 0, 7), isFalse);

      board.place(square, 0, 0, 2);
      expect(board.cellAt(0, 0), 3); // stored as colorIndex + 1
      expect(board.cellAt(1, 1), 3);
      expect(board.cellAt(0, 2), 0);
      expect(board.canPlace(square, 0, 0), isFalse); // occupied
      expect(board.canPlace(square, 0, 1), isFalse); // overlapping
      expect(board.canPlace(square, 0, 2), isTrue); // adjacent is fine
    });

    test('fullRows / fullCols detection', () {
      final board = Board();
      final dot = PieceShapes.byName('dot');
      for (var c = 0; c < Board.size; c++) {
        board.place(dot, 2, c, 0);
      }
      for (var r = 0; r < Board.size; r++) {
        board.place(dot, r, 5, 0);
      }
      expect(board.fullRows(), [2]);
      expect(board.fullCols(), [5]);

      // Clearing the intersection cell breaks both lines.
      board.clearCells(const [PieceCell(5, 2)]);
      expect(board.fullRows(), isEmpty);
      expect(board.fullCols(), isEmpty);
    });

    test('cellsInLines covers rows and columns without duplicates', () {
      final board = Board();
      final cells = board.cellsInLines({0}, {0});
      // Row 0 (8 cells) + column 0 (8 cells) - shared (0,0) = 15.
      expect(cells.length, 15);
      expect(cells.toSet().length, 15);
    });

    test('fitsAnywhere', () {
      final board = Board();
      final big = PieceShapes.byName('square3');
      final dot = PieceShapes.byName('dot');
      expect(board.fitsAnywhere(big), isTrue);

      // Fill everything except a 2x2 corner: square3 no longer fits,
      // but a dot still does.
      for (var r = 0; r < Board.size; r++) {
        for (var c = 0; c < Board.size; c++) {
          if (r >= 6 && c >= 6) continue;
          board.place(dot, r, c, 0);
        }
      }
      expect(board.fitsAnywhere(big), isFalse);
      expect(board.fitsAnywhere(dot), isTrue);

      board.place(dot, 6, 6, 0);
      board.place(dot, 6, 7, 0);
      board.place(dot, 7, 6, 0);
      board.place(dot, 7, 7, 0);
      expect(board.fitsAnywhere(dot), isFalse);
    });
  });
}
