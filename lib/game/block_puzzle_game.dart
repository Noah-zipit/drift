// The Flame game: owns the session, layout, drag input, scoring flow,
// overlays and audio wiring. Rendering stays in Flame; the Flutter HUD
// (score, mute, menus) lives in overlays so the widget tree never
// rebuilds per frame.

import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_service.dart';
import '../models/board.dart';
import '../models/game_logic.dart';
import '../theme/palette.dart';
import 'board_component.dart';
import 'effects.dart';
import 'piece_component.dart';
import 'tray_component.dart';

enum GamePhase { menu, playing, resolving, gameOver }

class _GhostTarget {
  _GhostTarget(this.row, this.col, this.valid, this.visible);

  final int row;
  final int col;
  final bool valid;
  final bool visible;
}

class BlockPuzzleGame extends FlameGame {
  static const _kBestKey = 'driftblocks.best_score';

  final Random _rng = Random();

  late GameSession session;
  late final AudioService audio;
  late final BoardComponent boardView;
  late final TrayComponent trayView;
  late final ScoreLayer scoreLayer;

  /// Observed by the Flutter HUD overlay (no per-frame widget rebuilds).
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> bestNotifier = ValueNotifier<int>(0);

  GamePhase _phase = GamePhase.menu;
  PieceComponent? _dragging;
  _GhostTarget? _ghostTarget;

  int _best = 0;
  int lastScore = 0;
  bool lastWasBest = false;

  bool _ready = false;

  // Layout metrics (logical pixels, safe-area aware via GameWidget).
  double cell = 40.0;
  Vector2 boardOrigin = Vector2.zero();

  @override
  Color backgroundColor() => Palette.background;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    audio = AudioService();
    await audio.init();

    _best = await _loadBest();
    bestNotifier.value = _best;

    session = GameSession(rng: _rng, colorCount: Palette.pieces.length);

    boardView = BoardComponent();
    trayView = TrayComponent();
    scoreLayer = ScoreLayer();
    await add(boardView);
    await add(trayView);
    await add(scoreLayer);

    _ready = true;
    _layout();
    overlays.add('start');
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_ready) {
      _layout();
    }
  }

  void _layout() {
    const hudReserve = 132.0; // room for the Flutter score HUD
    const trayReserve = 212.0; // room for the tray panel
    const margin = 20.0;

    final w = size.x;
    final h = size.y;
    final rawCell = min(
      (w - margin * 2) / Board.size,
      (h - hudReserve - trayReserve - 48) / Board.size,
    );
    cell = rawCell < 24.0 ? 24.0 : (rawCell > 64.0 ? 64.0 : rawCell);

    final boardPx = cell * Board.size;
    boardOrigin = Vector2(
      (w - boardPx) / 2,
      hudReserve + (h - hudReserve - trayReserve - boardPx) / 2,
    );
    boardView.layout(boardOrigin, cell);
    trayView.layout(w, h - trayReserve, trayReserve - 12, cell * 0.52);
  }

  // ------------------------------------------------------------ game flow

  /// Starts (or restarts) a run. Called from the Begin / Play-again
  /// buttons, i.e. always after a user gesture, so it also starts the
  /// ambient music (autoplay policy).
  Future<void> startGame() async {
    session = GameSession(rng: _rng, colorCount: Palette.pieces.length);
    session.refillTray();

    boardView.reset();
    trayView.spawnPieces(session.tray);
    for (final child in scoreLayer.children.toList()) {
      child.removeFromParent();
    }

    scoreNotifier.value = 0;
    lastScore = 0;
    lastWasBest = false;
    _dragging = null;
    _ghostTarget = null;

    _phase = GamePhase.playing;
    overlays.remove('start');
    overlays.remove('gameover');
    overlays.add('hud');

    await audio.startMusic();
    unawaited(audio.playTap());
  }

  void toMenu() {
    _phase = GamePhase.menu;
    _dragging = null;
    _ghostTarget = null;
    boardView.reset();
    trayView.clear();
    overlays.remove('gameover');
    overlays.remove('hud');
    overlays.add('start');
  }

  void _gameOver() {
    _phase = GamePhase.gameOver;
    lastScore = session.score;
    lastWasBest = session.score > _best;
    if (lastWasBest) {
      _best = session.score;
      bestNotifier.value = _best;
      unawaited(_saveBest());
    }
    unawaited(audio.playGameOver());
    overlays.remove('hud');
    overlays.add('gameover');
  }

  // ---------------------------------------------------------------- input
  //
  // Pointer events arrive from a Flutter GestureDetector wrapped around
  // the GameWidget (see main.dart), already in game-local coordinates.

  void handlePanStart(Vector2 pos) {
    if (_phase != GamePhase.playing || _dragging != null) {
      return;
    }
    final piece = trayView.pieceAt(pos);
    if (piece == null) {
      return;
    }
    _dragging = piece;
    piece.pickUp();
    _updateGhost(pos);
  }

  void handlePanUpdate(Vector2 pos) {
    final piece = _dragging;
    if (piece == null || _phase != GamePhase.playing) {
      return;
    }
    piece.dragTo(pos);
    _updateGhost(pos);
  }

  void handlePanEnd() {
    final piece = _dragging;
    _dragging = null;
    final target = _ghostTarget;
    _ghostTarget = null;
    boardView.clearGhost();
    if (piece == null || _phase != GamePhase.playing) {
      return;
    }
    if (target != null && target.visible && target.valid) {
      unawaited(_doPlace(piece, target.row, target.col));
    } else {
      piece.returnToTray();
    }
  }

  void _updateGhost(Vector2 pos) {
    final piece = _dragging;
    if (piece == null) {
      _ghostTarget = null;
      boardView.clearGhost();
      return;
    }
    final shape = piece.shape;
    // Use the piece's live rendered cell size (it grows to full board size
    // on pickup) and the board view's actual grid, so the tinted preview
    // hugs the dragged piece exactly instead of being drawn oversized.
    final c = piece.cellPx;
    final grid = boardView.cell;
    final topLeftX = pos.x - shape.width * c / 2;
    final topLeftY = pos.y - shape.height * c / 2;
    final col = ((topLeftX - boardView.origin.x) / grid).round();
    final row = ((topLeftY - boardView.origin.y) / grid).round();

    final overlaps = row < Board.size &&
        row + shape.height > 0 &&
        col < Board.size &&
        col + shape.width > 0;
    if (!overlaps) {
      _ghostTarget = _GhostTarget(row, col, false, false);
      boardView.clearGhost();
      return;
    }
    final valid = session.board.canPlace(shape, row, col);
    _ghostTarget = _GhostTarget(row, col, valid, true);
    boardView.setGhost(shape, row, col, valid);
  }

  Future<void> _doPlace(PieceComponent piece, int row, int col) async {
    _phase = GamePhase.resolving;

    final shape = piece.shape;
    final colorIndex = piece.colorIndex;
    final trayIndex = piece.trayIndex;
    piece.placed();
    trayView.removePiece(piece);

    final result = session.applyMove(trayIndex, row, col);
    boardView.placeCells(shape, row, col, colorIndex);
    scoreNotifier.value = session.score;

    // The single, very light tick. Nothing else buzzes.
    unawaited(HapticFeedback.selectionClick());
    unawaited(audio.playPlace());

    if (result.linesCleared > 0) {
      unawaited(audio.playClear(result.comboStreak));
      boardView.dissolveCells(result.clearedCells);

      final centres = <Vector2>[
        for (final cellPos in result.clearedCells)
          boardView.cellCentre(cellPos.y, cellPos.x),
      ];
      final colours = <Color>[
        for (final index in result.clearedColors)
          Palette.pieces[index % Palette.pieces.length],
      ];
      if (centres.isNotEmpty && colours.isNotEmpty) {
        scoreLayer.softSparkles(centres, colours, _rng);
      }

      scoreLayer.popup(
        '+${result.scoreGained}',
        Vector2(size.x / 2, boardOrigin.y - 24),
      );
      if (result.comboStreak >= 2) {
        scoreLayer.combo(
          GameSession.comboLabel(result.comboStreak),
          Vector2(size.x / 2, boardOrigin.y - 60),
        );
      }
      // Let the pop sweep finish before continuing
      // (max stagger ~0.28s + 0.52s pop).
      await Future.delayed(const Duration(milliseconds: 850));
    } else {
      await Future.delayed(const Duration(milliseconds: 120));
    }

    if (result.trayEmpty) {
      session.refillTray();
      trayView.spawnPieces(session.tray);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (session.isGameOver) {
      await Future.delayed(const Duration(milliseconds: 600));
      _gameOver();
    } else {
      _phase = GamePhase.playing;
    }
  }

  // ------------------------------------------------------------- persistence

  Future<int> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBestKey) ?? 0;
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBestKey, _best);
  }
}
