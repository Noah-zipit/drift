// Stack — one-tap tower builder. A block glides in from alternating sides;
// tap to set it down. The overhang shears off and tumbles away. Miss the
// tower and the run ends.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math.dart' as vm;

enum _Phase { moving, over }

class StackController {
  StackController();

  static const double blockH = 0.9;
  static const double startSize = 3.2;
  static const double slideRange = 5.2;
  static const double slideSpeed = 2.6;

  final Scene scene = Scene();
  late final PerspectiveCamera camera;

  final List<Node> tower = [];
  final List<Node> _debrisNodes = [];
  final List<double> _debrisVel = [];
  final List<double> _debrisSpin = [];

  late Node _mover; // the sliding block (unit cuboid, footprint in scale)
  _Phase phase = _Phase.moving;

  int score = 0;
  int best = 0;
  double _elapsed = 0;
  double _moveT = 0;
  int _axis = 0; // 0 = slides along X, 1 = along Z
  double _camY = 4.5;
  double _towerTop = 0;

  bool ready = false;
  void Function()? onScore;
  void Function()? onGameOver;

  static vm.Vector4 _linear(double r, double g, double b) {
    double c(double x) => math.pow(x, 2.2).toDouble();
    return vm.Vector4(c(r), c(g), c(b), 1.0);
  }

  /// Pastel gradient color for [layer], sRGB -> linear.
  vm.Vector4 _layerColor(int layer) {
    final hue = (0.52 + layer * 0.035) % 1.0;
    final c = _hsl(hue, 0.55, 0.62);
    return _linear(c[0], c[1], c[2]);
  }

  List<double> _hsl(double h, double s, double l) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h * 6) % 2 - 1).abs());
    final m = l - c / 2;
    late List<double> rgb;
    switch ((h * 6).floor() % 6) {
      case 0: rgb = [c, x, 0]; break;
      case 1: rgb = [x, c, 0]; break;
      case 2: rgb = [0, c, x]; break;
      case 3: rgb = [0, x, c]; break;
      case 4: rgb = [x, 0, c]; break;
      default: rgb = [c, 0, x]; break;
    }
    return [rgb[0] + m, rgb[1] + m, rgb[2] + m];
  }

  Future<void> init() async {
    await Scene.initializeStaticResources();
    final prefs = await SharedPreferences.getInstance();
    best = prefs.getInt('stack_best') ?? 0;

    camera = PerspectiveCamera(
      fovRadiansY: 40 * math.pi / 180,
      position: vm.Vector3(7.5, 6.5, 7.5),
      target: vm.Vector3(0, 1.5, 0),
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.4, -1.0, -0.3),
      color: vm.Vector3(1.0, 0.98, 0.95),
      intensity: 2.4,
    );
    final rim = Node()..position = vm.Vector3(-6, 3, -4);
    rim.addComponent(
      PointLightComponent(
        PointLight(color: vm.Vector3(0.45, 0.75, 0.85), intensity: 20, range: 30),
      ),
    );
    scene.add(rim);

    // Base platform.
    final base = Node(mesh: Mesh(CuboidGeometry(vm.Vector3(1, 1, 1)),
        _mat(vm.Vector4(0.05, 0.09, 0.10, 1.0), 0.6, 0.1)));
    base.scale = vm.Vector3(startSize + 1.2, 0.6, startSize + 1.2);
    base.position = vm.Vector3(0, -0.3, 0);
    scene.add(base);

    _spawnBase();
    _spawnMover();
    ready = true;
  }

  PhysicallyBasedMaterial _mat(vm.Vector4 color, double rough, double metal) {
    final m = PhysicallyBasedMaterial();
    m.baseColorFactor = color;
    m.roughnessFactor = rough;
    m.metallicFactor = metal;
    return m;
  }

  void _spawnBase() {
    final node = Node(
      mesh: Mesh(CuboidGeometry(vm.Vector3(1, 1, 1)),
          _mat(_layerColor(0), 0.45, 0.05)),
    );
    node.scale = vm.Vector3(startSize, blockH, startSize);
    node.position = vm.Vector3(0, blockH / 2, 0);
    scene.add(node);
    tower.add(node);
    _towerTop = blockH;
    score = 0;
  }

  void _spawnMover() {
    _axis = tower.length % 2 == 0 ? 0 : 1;
    final prev = tower.last;
    final w = prev.scale.x;
    final d = prev.scale.z;
    _mover = Node(
      mesh: Mesh(CuboidGeometry(vm.Vector3(1, 1, 1)),
          _mat(_layerColor(tower.length), 0.45, 0.05)),
    );
    _mover.scale = vm.Vector3(w, blockH, d);
    _mover.position = vm.Vector3(0, _towerTop + blockH / 2, 0);
    scene.add(_mover);
    _moveT = math.Random().nextDouble() * math.pi * 2;
    phase = _Phase.moving;
  }

  void onTick(Duration elapsed, double dtRaw) {
    if (!ready) return;
    final dt = math.min(dtRaw, 0.05);
    _elapsed += dt;

    if (phase == _Phase.moving) {
      _moveT += dt * slideSpeed;
      final off = math.sin(_moveT) * slideRange;
      final p = _mover.position;
      _mover.position = _axis == 0
          ? vm.Vector3(off, p.y, 0)
          : vm.Vector3(0, p.y, off);
    }

    // Debris physics: fall + tumble, cull far below.
    for (var i = _debrisNodes.length - 1; i >= 0; i--) {
      final n = _debrisNodes[i];
      _debrisVel[i] -= dt * 22;
      final p = n.position;
      n.position = vm.Vector3(p.x, p.y + _debrisVel[i] * dt, p.z);
      n.rotation = vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            _debrisSpin[i] * _elapsed,
          ) *
          vm.Quaternion.axisAngle(
              vm.Vector3(1, 0, 0), _debrisSpin[i] * 0.6 * _elapsed);
      if (p.y < _camY - 16) {
        scene.remove(n);
        _debrisNodes.removeAt(i);
        _debrisVel.removeAt(i);
        _debrisSpin.removeAt(i);
      }
    }

    // Camera eases up with the tower.
    final targetY = _towerTop + 3.2;
    _camY += (targetY - _camY) * math.min(1, dt * 3);
    camera.position = vm.Vector3(7.5, _camY + 2.0, 7.5);
    camera.target = vm.Vector3(0, _camY - 1.2, 0);
  }

  /// Player tap: freeze the slider, shear the overhang.
  void tap() {
    if (!ready || phase != _Phase.moving) return;
    final prev = tower.last;
    final px = prev.position.x, pz = prev.position.z;
    final mx = _mover.position.x, mz = _mover.position.z;
    final pw = prev.scale.x, pd = prev.scale.z;
    final mw = _mover.scale.x, md = _mover.scale.z;

    if (_axis == 0) {
      final left = math.max(px - pw / 2, mx - mw / 2);
      final right = math.min(px + pw / 2, mx + mw / 2);
      final overlap = right - left;
      if (overlap <= 0.05) {
        _miss();
        return;
      }
      _shearDebrisX(mx, mw, px, pw, md, mz);
      _mover.position = vm.Vector3((left + right) / 2, _mover.position.y, mz);
      _mover.scale = vm.Vector3(overlap, blockH, md);
    } else {
      final near = math.max(pz - pd / 2, mz - md / 2);
      final far = math.min(pz + pd / 2, mz + md / 2);
      final overlap = far - near;
      if (overlap <= 0.05) {
        _miss();
        return;
      }
      _shearDebrisZ(mz, md, pz, pd, mw, mx);
      _mover.position = vm.Vector3(mx, _mover.position.y, (near + far) / 2);
      _mover.scale = vm.Vector3(mw, blockH, overlap);
    }

    tower.add(_mover);
    _towerTop += blockH;
    score = tower.length - 1;
    if (score > best) {
      best = score;
      SharedPreferences.getInstance().then((p) => p.setInt('stack_best', best));
    }
    onScore?.call();
    _spawnMover();
  }

  void _shearDebrisX(
      double mx, double mw, double px, double pw, double md, double mz) {
    final mLeft = mx - mw / 2, mRight = mx + mw / 2;
    final pLeft = px - pw / 2, pRight = px + pw / 2;
    double cutCenter, cutSize;
    if (mLeft < pLeft - 0.01) {
      cutCenter = (mLeft + pLeft) / 2;
      cutSize = pLeft - mLeft;
    } else if (mRight > pRight + 0.01) {
      cutCenter = (pRight + mRight) / 2;
      cutSize = mRight - pRight;
    } else {
      return; // near-perfect: nothing to shear
    }
    _dropPiece(
      vm.Vector3(cutSize, blockH, md),
      vm.Vector3(cutCenter, _towerTop + blockH / 2, mz),
    );
  }

  void _shearDebrisZ(
      double mz, double md, double pz, double pd, double mw, double mx) {
    final mNear = mz - md / 2, mFar = mz + md / 2;
    final pNear = pz - pd / 2, pFar = pz + pd / 2;
    double cutCenter, cutSize;
    if (mNear < pNear - 0.01) {
      cutCenter = (mNear + pNear) / 2;
      cutSize = pNear - mNear;
    } else if (mFar > pFar + 0.01) {
      cutCenter = (pFar + mFar) / 2;
      cutSize = mFar - pFar;
    } else {
      return;
    }
    _dropPiece(
      vm.Vector3(mw, blockH, cutSize),
      vm.Vector3(mx, _towerTop + blockH / 2, cutCenter),
    );
  }

  void _dropPiece(vm.Vector3 size, vm.Vector3 at) {
    final n = Node(
      mesh: Mesh(CuboidGeometry(vm.Vector3(1, 1, 1)),
          _mat(_layerColor(tower.length), 0.5, 0.05)),
    );
    n.scale = size;
    n.position = at;
    scene.add(n);
    _debrisNodes.add(n);
    _debrisVel.add(0);
    _debrisSpin.add((math.Random().nextDouble() - 0.5) * 6);
  }

  void _miss() {
    _dropPiece(
      _mover.scale.clone(),
      vm.Vector3(_mover.position.x, _towerTop + blockH / 2, _mover.position.z),
    );
    scene.remove(_mover);
    phase = _Phase.over;
    onGameOver?.call();
  }

  void restart() {
    for (final n in tower) {
      scene.remove(n);
    }
    tower.clear();
    for (final n in _debrisNodes) {
      scene.remove(n);
    }
    _debrisNodes.clear();
    _debrisVel.clear();
    _debrisSpin.clear();
    _towerTop = 0;
    _camY = 4.5;
    _spawnBase();
    _spawnMover();
  }

  void handleDown(ui.Offset pos, ui.Size size) {}
}
