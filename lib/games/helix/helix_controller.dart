// Helix — guide the bouncing ball down the spiral tower.
// Drag horizontally to rotate the tower. Press and hold (without dragging)
// to smash straight down through platforms. Landing on red while not
// smashing ends the run.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math.dart' as vm;

class _Sector {
  _Sector({required this.node, required this.red, required this.angle});
  final Node node;
  final bool red;
  final double angle; // center angle in tower-local radians
}

class _Level {
  _Level({required this.y, required this.node});
  final double y;
  final Node node;
  final List<_Sector> sectors = [];
  bool passed = false;
}

class HelixController {
  HelixController();

  static const int sectorsPerLevel = 10;
  static const double levelGap = 3.2;
  static const double towerR = 0.5;
  static const double platInner = 0.7;
  static const double platOuter = 2.7;
  static const double platThick = 0.35;
  static const double ballR = 0.32;
  static const double gravity = 32.0;
  static const double bounceV = 13.0;
  static const double smashV = -26.0;

  final Scene scene = Scene();
  late final PerspectiveCamera camera;
  late final Node tower; // rotates with drag
  late final Node ball;

  final List<_Level> levels = [];
  double _ballY = 0;
  double _vy = 0;
  bool _smashing = false;
  bool _fingerDown = false;
  double _downTime = 0;
  bool _moved = false;
  double _towerAngle = 0;
  double _elapsed = 0;
  int _levelCount = 0;

  int score = 0;
  int best = 0;
  bool over = false;

  bool ready = false;
  void Function()? onScore;
  void Function()? onGameOver;

  static vm.Vector4 _linear(double r, double g, double b) {
    double c(double x) => math.pow(x, 2.2).toDouble();
    return vm.Vector4(c(r), c(g), c(b), 1.0);
  }

  Future<void> init() async {
    await Scene.initializeStaticResources();
    final prefs = await SharedPreferences.getInstance();
    best = prefs.getInt('helix_best') ?? 0;

    camera = PerspectiveCamera(
      fovRadiansY: 42 * math.pi / 180,
      position: vm.Vector3(5.2, 4.6, 5.2),
      target: vm.Vector3(0.9, -1.0, 0),
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.4, -1.0, -0.3),
      color: vm.Vector3(1.0, 0.98, 0.95),
      intensity: 2.5,
    );
    final accent = Node()..position = vm.Vector3(-5, 2, 4);
    accent.addComponent(
      PointLightComponent(
        PointLight(color: _linear(1.0, 0.44, 0.38).xyz, intensity: 25, range: 30),
      ),
    );
    scene.add(accent);

    tower = Node();
    scene.add(tower);

    // Central column (tall; extended as the tower grows).
    final column = Node(
      mesh: Mesh(
        CylinderGeometry(bottomRadius: towerR, topRadius: towerR, height: 400),
        _mat(_linear(0.07, 0.13, 0.14), 0.55, 0.2),
      ),
    );
    column.position = vm.Vector3(0, -190, 0);
    tower.add(column);

    // Ball.
    ball = Node(
      mesh: Mesh(
        SphereGeometry(radius: ballR, segments: 24, rings: 16),
        _mat(_linear(0.91, 0.95, 0.93), 0.25, 0.1),
      ),
    );
    scene.add(ball);

    // First levels: safe landing pad + a few gentle ones.
    _addLevel(0, safe: true);
    for (var i = 1; i < 6; i++) {
      _addLevel(-i * levelGap, safe: i < 3);
    }
    _ballY = platThick / 2 + ballR + 0.01;
    _vy = 0;
    ready = true;
  }

  PhysicallyBasedMaterial _mat(vm.Vector4 color, double rough, double metal) {
    final m = PhysicallyBasedMaterial();
    m.baseColorFactor = color;
    m.roughnessFactor = rough;
    m.metallicFactor = metal;
    return m;
  }

  void _addLevel(double y, {bool safe = false}) {
    final node = Node();
    node.position = vm.Vector3(0, y, 0);
    tower.add(node);
    final level = _Level(y: y, node: node);
    final r = math.Random();
    final slot = math.pi * 2 / sectorsPerLevel;

    // Choose gaps and red sectors.
    final missing = <int>{};
    final gapCount = 2 + r.nextInt(2);
    while (missing.length < gapCount) {
      missing.add(r.nextInt(sectorsPerLevel));
    }
    final reds = <int>{};
    if (!safe) {
      final redCount = 1 + r.nextInt(2);
      var guard = 0;
      while (reds.length < redCount && guard++ < 40) {
        final s = r.nextInt(sectorsPerLevel);
        if (!missing.contains(s)) reds.add(s);
      }
    }

    final mid = (platInner + platOuter) / 2;
    final depth = platOuter - platInner;
    final hueBase = (_levelCount * 0.045) % 1.0;
    for (var i = 0; i < sectorsPerLevel; i++) {
      if (missing.contains(i)) continue;
      final angle = i * slot;
      final span = slot * 0.86;
      final width = 2 * mid * math.sin(span / 2);
      final isRed = reds.contains(i);
      final color = isRed
          ? _linear(0.95, 0.32, 0.28)
          : _teal(hueBase, i);
      final sector = Node(
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(1, 1, 1)),
          _mat(color, 0.4, 0.08),
        ),
      );
      sector.scale = vm.Vector3(depth, platThick, width);
      sector.position = vm.Vector3(
        mid * math.cos(angle),
        0,
        mid * math.sin(angle),
      );
      sector.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        -angle,
      );
      node.add(sector);
      level.sectors.add(_Sector(node: sector, red: isRed, angle: angle));
    }
    levels.add(level);
    _levelCount++;
  }

  vm.Vector4 _teal(double hueBase, int i) {
    // Deep teal gradient shifting with height.
    final h = (0.48 + hueBase + i * 0.004) % 1.0;
    final s = 0.5, l = 0.30 + (i % 3) * 0.02;
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h * 6) % 2 - 1).abs());
    final m = l - c / 2;
    final hh = (h * 6).floor() % 6;
    late List<double> rgb;
    switch (hh) {
      case 0: rgb = [c, x, 0]; break;
      case 1: rgb = [x, c, 0]; break;
      case 2: rgb = [0, c, x]; break;
      case 3: rgb = [0, x, c]; break;
      case 4: rgb = [x, 0, c]; break;
      default: rgb = [c, 0, x]; break;
    }
    return _linear(rgb[0] + m, rgb[1] + m, rgb[2] + m);
  }

  void onTick(Duration elapsed, double dtRaw) {
    if (!ready || over) return;
    final dt = math.min(dtRaw, 0.05);
    _elapsed += dt;

    // Press-and-hold (still) arms the smash.
    if (_fingerDown && !_moved && !_smashing) {
      if (_elapsed - _downTime > 0.18) _smashing = true;
    }

    _vy -= gravity * dt;
    if (_smashing) _vy = smashV;
    final prevY = _ballY;
    _ballY += _vy * dt;

    // Check each level crossed this frame (topmost first).
    for (final level in levels) {
      final top = level.y + platThick / 2 + ballR;
      if (prevY >= top && _ballY <= top && _vy <= 0) {
        _hitLevel(level, top);
        if (over) break;
      }
      // Score + cleanup for fully passed levels.
      if (!level.passed && _ballY < level.y - 1.0) {
        level.passed = true;
        score++;
        if (score > best) {
          best = score;
          SharedPreferences.getInstance()
              .then((p) => p.setInt('helix_best', best));
        }
        onScore?.call();
      }
    }

    // Endless: add below, remove far above.
    final lowest = levels.last.y;
    if (_ballY < lowest + levelGap * 4) {
      _addLevel(lowest - levelGap);
    }
    while (levels.length > 2 && levels.first.y > _ballY + 12) {
      final old = levels.removeAt(0);
      tower.remove(old.node);
    }

    ball.position = vm.Vector3(
      (platInner + platOuter) / 2,
      _ballY,
      0,
    );
    // Squash on smash for juice.
    final squash = _smashing ? 0.82 : 1.0;
    ball.scale = vm.Vector3(1 / squash, squash, 1 / squash);

    // Camera follows the ball.
    camera.position = vm.Vector3(5.2, _ballY + 4.0, 5.2);
    camera.target = vm.Vector3(0.9, _ballY - 1.3, 0);
  }

  void _hitLevel(_Level level, double top) {
    // Ball angle in tower-local space (ball sits at world +X).
    var local = (-_towerAngle) % (math.pi * 2);
    if (local < 0) local += math.pi * 2;
    final slot = math.pi * 2 / sectorsPerLevel;
    _Sector? hit;
    for (final s in level.sectors) {
      var d = (local - s.angle).abs() % (math.pi * 2);
      if (d > math.pi) d = math.pi * 2 - d;
      if (d < slot * 0.43) {
        hit = s;
        break;
      }
    }
    if (hit == null) return; // gap: keep falling

    if (_smashing) {
      // Smash through: break the sector, keep diving.
      level.node.remove(hit.node);
      level.sectors.remove(hit);
      _vy = smashV;
      return;
    }
    if (hit.red) {
      over = true;
      onGameOver?.call();
      return;
    }
    // Clean bounce.
    _ballY = top;
    _vy = bounceV;
  }

  void handleDown(ui.Offset pos, ui.Size size) {
    _fingerDown = true;
    _downTime = _elapsed;
    _moved = false;
  }

  void handleMove(ui.Offset pos, ui.Offset delta) {
    if (!_fingerDown) return;
    if (delta.dx.abs() > 1) _moved = true;
    _towerAngle += delta.dx * 0.012;
    tower.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      _towerAngle,
    );
  }

  void handleUp() {
    _fingerDown = false;
    _smashing = false;
  }

  void restart() {
    for (final l in levels) {
      tower.remove(l.node);
    }
    levels.clear();
    _levelCount = 0;
    score = 0;
    over = false;
    _smashing = false;
    _towerAngle = 0;
    tower.rotation = vm.Quaternion.identity();
    _addLevel(0, safe: true);
    for (var i = 1; i < 6; i++) {
      _addLevel(-i * levelGap, safe: i < 3);
    }
    _ballY = platThick / 2 + ballR + 0.01;
    _vy = 0;
  }
}
