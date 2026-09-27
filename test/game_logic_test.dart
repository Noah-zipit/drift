import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:block_puzzle/models/board.dart';
import 'package:block_puzzle/models/game_logic.dart';
import 'package:block_puzzle/models/piece_shape.dart';

void main() {
  PieceShape dot() => PieceShapes.byName('dot');

  group('GameSession', () {
    test('refillTray deals three pieces', () {
      final session = GameSession(rng: Random(7));
      session.refillTray();
      expect(session.tray.whereType<TrayPiece>().length, 3);
      expect(session.trayEmpty, isFalse);
    });

    test('placement scores cells, no clear resets streak', () {
      final session = GameSession(rng: Random(7));
      session.tray[0] = TrayPiece(PieceShapes.byName('square2'), 1);
      final result = session.applyMove(0, 0, 0);

      expect(result.scoreGained, 4); // 4 cells, no lines
      expect(result.linesCleared, 0);
      expect(result.comboStreak, 0);
      expect(session.score, 4);
      expect(session.comboStreak, 0);
      expect(session.tray[0], isNull);
      expect(result.trayEmpty, isFalse);
    });

    test('completing a line scores cells + 10 * lines^2 * streak', () {
      final session = GameSession(rng: Random(7));
      // Fill row 0 except the last cell.
      for (var c = 0; c < Board.size - 1; c++) {
        session.board.place(dot(), 0, c, 0);
      }
      session.tray[0] = TrayPiece(dot(), 3);

      final result = session.applyMove(0, 0, Board.size - 1);

      expect(result.linesCleared, 1);
      expect(result.comboStreak, 1);
      expect(result.scoreGained, 1 + 10); // 1 cell + 10*1*1*1
      expect(session.score, 11);
      expect(result.clearedCells.length, Board.size);
      // The cleared row is empty again.
      for (var c = 0; c < Board.size; c++) {
        expect(session.board.cellAt(0, c), 0);
      }
    });

    test('consecutive clears build an escalating combo streak', () {
      final session = GameSession(rng: Random(7));
      // Prepare rows 0 and 1, each missing their last cell.
      for (var c = 0; c < Board.size - 1; c++) {
        session.board.place(dot(), 0, c, 0);
        session.board.place(dot(), 1, c, 0);
      }
      session.tray[0] = TrayPiece(dot(), 0);
      session.tray[1] = TrayPiece(dot(), 0);

      final first = session.applyMove(0, 0, Board.size - 1);
      expect(first.comboStreak, 1);
      expect(first.scoreGained, 1 + 10);

      final second = session.applyMove(1, 1, Board.size - 1);
      expect(second.comboStreak, 2);
      expect(second.scoreGained, 1 + 10 * 1 * 1 * 2); // streak multiplies
      expect(session.score, 11 + 21);

      // A non-clearing move resets the streak.
      session.tray[2] = TrayPiece(dot(), 0);
      final third = session.applyMove(2, 4, 4);
      expect(third.comboStreak, 0);
      expect(session.comboStreak, 0);
    });

    test('simultaneous row + column clear scores both', () {
      final session = GameSession(rng: Random(7));
      // Row 3 and column 3 complete except their intersection (3,3).
      for (var i = 0; i < Board.size; i++) {
        if (i != 3) {
          session.board.place(dot(), 3, i, 0);
          session.board.place(dot(), i, 3, 0);
        }
      }
      session.tray[0] = TrayPiece(dot(), 0);
      final result = session.applyMove(0, 3, 3);

      expect(result.linesCleared, 2);
      expect(result.scoreGained, 1 + 10 * 2 * 2 * 1); // 1 + 40
      expect(result.clearedCells.length, 2 * Board.size - 1);
      expect(session.board.cellAt(3, 3), 0);
    });

    test('isGameOver only when nothing fits', () {
      final session = GameSession(rng: Random(7));
      session.refillTray();
      expect(session.isGameOver, isFalse); // empty board fits everything

      // Fill the board completely: nothing can fit.
      for (var r = 0; r < Board.size; r++) {
        for (var c = 0; c < Board.size; c++) {
          session.board.place(dot(), r, c, 0);
        }
      }
      expect(session.isGameOver, isTrue);
    });

    test('illegal moves throw', () {
      final session = GameSession(rng: Random(7));
      session.tray[0] = TrayPiece(PieceShapes.byName('square2'), 0);
      // Out of bounds.
      expect(() => session.applyMove(0, 7, 7), throwsStateError);
      // Empty slot.
      expect(() => session.applyMove(1, 0, 0), throwsStateError);
    });

    test('comboLabel is quiet and elegant', () {
      expect(GameSession.comboLabel(2), 'Double clear');
      expect(GameSession.comboLabel(3), 'Triple clear');
      expect(GameSession.comboLabel(4), 'Quadruple clear');
      expect(GameSession.comboLabel(5), contains('5'));
    });
  });
}
