// Playable Rubik's cube — a faithful port of the portfolio's CubeSpecimen.
// Dark glossy cubies, jewel-tone stickers, drag a face to twist its layer,
// drag the void to orbit. Idle float + slow spin, auto-twist when untouched.
// Nothing else: no score, no timer, no chrome.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class _Twist {
  _Twist({
    required this.pivot,
    required this.members,
    required this.axis,
    required this.dir,
  });
  final Node pivot;
  final List<int> members;
  final int axis;
  final int dir;
  double t = 0;
  static const dur = 0.55;
}

class _Drag {
  _Drag.twist({
    required this.normal,
    required this.normalAxis,
    required this.planePoint,
    required this.planeNormal,
    required this.grid,
    required this.startX,
    required this.startY,
  }) : mode = _DragMode.twist,
       lastX = startX,
       lastY = startY;

  _Drag.orbit({required this.lastX, required this.lastY})
    : mode = _DragMode.orbit,
      normal = vm.Vector3.zero(),
      normalAxis = 0,
      planePoint = vm.Vector3.zero(),
      planeNormal = vm.Vector3.zero(),
      grid = vm.Vector3.zero(),
      startX = 0,
      startY = 0;

  final _DragMode mode;
  final vm.Vector3 normal; // holder-local unit normal of grabbed face
  final int normalAxis;
  final vm.Vector3 planePoint; // holder-local grab point
  final vm.Vector3 planeNormal; // holder-local plane normal (= normal)
  final vm.Vector3 grid; // integer grid coords of grabbed cubie
  final double startX, startY; // screen px at grab
  double lastX, lastY;
  bool consumed = false;
}

enum _DragMode { twist, orbit }

class CubeController {
  CubeController();

  // ---- portfolio constants ----
  static const double spacing = 1.02;
  static const double cubieSize = 0.96;
  static const double stickerHalf = 0.32;
  static const double stickerRadius = 0.09;
  static const double stickerLift = 0.015;
  static const double dragPx = 14.0;

  // Face colors, sRGB hex (portfolio exact).
  static const int colPX = 0xFFFF6F61; // +X coral
  static const int colNX = 0xFFD98E3B; // -X amber
  static const int colPY = 0xFFE9F2ED; // +Y foam
  static const int colNY = 0xFFC9A227; // -Y gold
  static const int colPZ = 0xFF2E8B7A; // +Z teal
  static const int colNZ = 0xFF2B5F9E; // -Z blue
  static const int colPlastic = 0xFF121619;

  final Scene scene = Scene();
  late final PerspectiveCamera camera;

  late final Node orbit;
  late final Node spin;
  late final Node holder;
  late final Node ring;

  final List<Node> cubies = [];
  final List<vm.Vector3> grids = [];
  final Map<Node, int> _cubieIndex = {};

  _Twist? _twist;
  _Drag? _drag;

  double _elapsed = 0;
  double _idle = 10;
  double _autoTimer = 0;
  double _yaw = 0;
  double _pitch = 0;

  bool ready = false;
  ui.Size _viewSize = ui.Size.zero;

  static vm.Vector4 _linear(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    double c(double x) => math.pow(x, 2.2).toDouble();
    return vm.Vector4(c(r), c(g), c(b), 1.0);
  }

  Future<void> init() async {
    await Scene.initializeStaticResources();

    camera = PerspectiveCamera(
      fovRadiansY: 42 * math.pi / 180,
      position: vm.Vector3(5.2, 3.4, 6.4),
      target: vm.Vector3(0, 0, 0),
    );

    // Key light: soft white from upper right, like the portfolio.
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.45, -1.0, -0.35),
      color: vm.Vector3(1.0, 0.98, 0.95),
      intensity: 2.6,
    );
    // Coral accent from the left.
    final coralNode = Node()..position = vm.Vector3(-5, 1.5, 3);
    coralNode.addComponent(
      PointLightComponent(
        PointLight(color: _linear(colPX).xyz, intensity: 30, range: 20),
      ),
    );
    scene.add(coralNode);
    // Cool fill from below-right so the dark plastic never goes pure black.
    final fillNode = Node()..position = vm.Vector3(3, -4, 4);
    fillNode.addComponent(
      PointLightComponent(
        PointLight(
          color: vm.Vector3(0.35, 0.55, 0.6),
          intensity: 12,
          range: 25,
        ),
      ),
    );
    scene.add(fillNode);

    orbit = Node();
    spin = Node()..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0.6);
    holder = Node();
    spin.add(holder);
    orbit.add(spin);
    scene.add(orbit);

    // Decorative foam ring, as on the portfolio.
    ring = Node(
      mesh: Mesh(
        TorusGeometry(
          radius: 2.6,
          tubeRadius: 0.012,
          radialSegments: 12,
          tubularSegments: 140,
        ),
        _basic(_linear(0xFFE9F2ED), 0.25),
      ),
    );
    ring.rotation =
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.3);
    ring.position = vm.Vector3(0, 0.1, 0);
    scene.add(ring);

    _buildCubies();
    ready = true;
  }

  PhysicallyBasedMaterial _plastic() {
    final m = PhysicallyBasedMaterial();
    m.baseColorFactor = _linear(colPlastic);
    m.roughnessFactor = 0.32;
    m.metallicFactor = 0.15;
    return m;
  }

  PhysicallyBasedMaterial _sticker(int argb) {
    final m = PhysicallyBasedMaterial();
    m.baseColorFactor = _linear(argb);
    m.roughnessFactor = 0.26;
    m.metallicFactor = 0.0;
    return m;
  }

  UnlitMaterial _basic(vm.Vector4 color, double opacity) {
    final m = UnlitMaterial();
    m.baseColorFactor = vm.Vector4(color.x, color.y, color.z, opacity);
    m.alphaMode = AlphaMode.blend;
    // UnlitMaterial ignores lights; used for the faint ring.
    return m;
  }

  void _buildCubies() {
    final bodyGeo = CuboidGeometry(vm.Vector3.all(cubieSize));
    final stickerGeo = _roundedRect(stickerHalf, stickerRadius);
    final plastic = _plastic();

    var index = 0;
    for (var x = -1; x <= 1; x++) {
      for (var y = -1; y <= 1; y++) {
        for (var z = -1; z <= 1; z++) {
          final cubie = Node(mesh: Mesh(bodyGeo, plastic));
          cubie.position = vm.Vector3(
            x * spacing,
            y * spacing,
            z * spacing,
          );
          _addSticker(cubie, stickerGeo, 0, x, y, z);
          holder.add(cubie);
          cubies.add(cubie);
          grids.add(vm.Vector3(x.toDouble(), y.toDouble(), z.toDouble()));
          _cubieIndex[cubie] = index++;
        }
      }
    }
  }

  void _addSticker(Node cubie, MeshGeometry geo, int face, int x, int y, int z) {
    // face: 0:+X 1:-X 2:+Y 3:-Y 4:+Z 5:-Z
    const faceCoord = [1, -1, 1, -1, 1, -1];
    const faceAxis = [0, 0, 1, 1, 2, 2];
    if ((faceAxis[face] == 0 ? x : faceAxis[face] == 1 ? y : z) !=
        faceCoord[face]) {
      return;
    }
    const colors = [colPX, colNX, colPY, colNY, colPZ, colNZ];
    final sticker = Node(mesh: Mesh(geo, _sticker(colors[face])));
    final d = cubieSize / 2 + stickerLift;
    switch (face) {
      case 0:
        sticker.position = vm.Vector3(d, 0, 0);
        sticker.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2);
      case 1:
        sticker.position = vm.Vector3(-d, 0, 0);
        sticker.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -math.pi / 2);
      case 2:
        sticker.position = vm.Vector3(0, d, 0);
        sticker.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -math.pi / 2);
      case 3:
        sticker.position = vm.Vector3(0, -d, 0);
        sticker.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2);
      case 4:
        sticker.position = vm.Vector3(0, 0, d);
      case 5:
        sticker.position = vm.Vector3(0, 0, -d);
        sticker.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    }
    cubie.add(sticker);
    _cubieIndex[sticker] = _cubieIndex[cubie]!;
  }

  /// Rounded-rectangle plane (XY, facing +Z), triangle fan from center.
  MeshGeometry _roundedRect(double half, double radius) {
    const cornerSegs = 6;
    final positions = <double>[0, 0, 0];
    final normals = <double>[0, 0, 1];
    final uvs = <double>[0.5, 0.5];
    // Perimeter: 4 corners, each swept 90°.
    final corners = [
      [half - radius, half - radius, 0.0],
      [-(half - radius), half - radius, math.pi / 2],
      [-(half - radius), -(half - radius), math.pi],
      [half - radius, -(half - radius), 3 * math.pi / 2],
    ];
    for (final c in corners) {
      final cx = c[0], cy = c[1], start = c[2];
      for (var i = 0; i <= cornerSegs; i++) {
        final a = start + (i / cornerSegs) * (math.pi / 2);
        final px = cx + radius * math.cos(a);
        final py = cy + radius * math.sin(a);
        positions.addAll([px, py, 0]);
        normals.addAll([0, 0, 1]);
        uvs.addAll([px / (2 * half) + 0.5, py / (2 * half) + 0.5]);
      }
    }
    final indices = <int>[];
    final ringCount = positions.length ~/ 3 - 1;
    for (var i = 1; i <= ringCount; i++) {
      final next = i % ringCount + 1;
      indices.addAll([0, i, next]);
    }
    return MeshGeometry.fromArrays(
      positions: Float32List.fromList(positions),
      normals: Float32List.fromList(normals),
      texCoords: Float32List.fromList(uvs),
      indices: indices,
    );
  }

  // ---------------- per-frame ----------------

  void onTick(Duration elapsed, double dtRaw) {
    if (!ready) return;
    final dt = math.min(dtRaw, 0.05);
    _elapsed += dt;
    _idle += dt;

    // Idle float + slow spin on the spin group (portfolio values).
    spin.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      0.6 + _elapsed * 0.1,
    );
    final pos = spin.position;
    spin.position = vm.Vector3(pos.x, math.sin(_elapsed * 0.8) * 0.09, pos.z);
    ring.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      _elapsed * 0.1,
    ) * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.3);

    final tw = _twist;
    if (tw == null) {
      if (_idle > 6 && _drag == null) {
        _autoTimer += dt;
        if (_autoTimer > 2.6) {
          _autoTimer = 0;
          final r = math.Random();
          _triggerTwist(r.nextInt(3), r.nextInt(3) - 1, r.nextBool() ? 1 : -1);
        }
      }
    } else {
      tw.t += dt;
      final p = math.min(1.0, tw.t / _Twist.dur);
      final angle = tw.dir * (math.pi / 2) * _easeInOutCubic(p);
      final axisVec = vm.Vector3.zero();
      axisVec[tw.axis] = 1.0;
      tw.pivot.rotation = vm.Quaternion.axisAngle(axisVec, angle);
      if (p >= 1) _finishTwist(tw);
    }
  }

  double _easeInOutCubic(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

  // ---------------- twist ----------------

  void _triggerTwist(int axis, int layer, int dir) {
    if (_twist != null) return;
    final pivot = Node();
    holder.add(pivot);
    final members = <int>[];
    for (var i = 0; i < cubies.length; i++) {
      if (grids[i][axis].round() == layer) members.add(i);
    }
    if (members.isEmpty) {
      holder.remove(pivot);
      return;
    }
    for (final i in members) {
      _reparent(cubies[i], pivot);
    }
    _twist = _Twist(pivot: pivot, members: members, axis: axis, dir: dir);
  }

  void _finishTwist(_Twist tw) {
    for (final i in tw.members) {
      final g = grids[i];
      final ng = _rotateGrid(g, tw.axis, tw.dir);
      grids[i] = ng;
      _reparent(cubies[i], holder);
      cubies[i].position = vm.Vector3(
        ng.x * spacing,
        ng.y * spacing,
        ng.z * spacing,
      );
      _snapRotation(cubies[i]);
    }
    holder.remove(tw.pivot);
    _twist = null;
  }

  vm.Vector3 _rotateGrid(vm.Vector3 g, int axis, int dir) {
    final x = g.x, y = g.y, z = g.z;
    if (axis == 0) return vm.Vector3(x, -dir * z, dir * y);
    if (axis == 1) return vm.Vector3(dir * z, y, -dir * x);
    return vm.Vector3(-dir * y, dir * x, z);
  }

  void _snapRotation(Node n) {
    final q = math.pi / 2;
    final e = _toEuler(n.rotation);
    n.rotation = _fromEuler(
      (e.x / q).round() * q,
      (e.y / q).round() * q,
      (e.z / q).round() * q,
    );
  }

  vm.Vector3 _toEuler(vm.Quaternion quat) {
    final m = vm.Matrix4.compose(
      vm.Vector3.zero(),
      quat,
      vm.Vector3.all(1),
    );
    // Extract XYZ euler.
    final sy = (-m[8]).clamp(-1.0, 1.0);
    if (sy.abs() < 0.99999) {
      return vm.Vector3(
        math.atan2(m[9], m[10]),
        math.asin(sy),
        math.atan2(m[4], m[0]),
      );
    }
    return vm.Vector3(
      math.atan2(-m[6], m[5]),
      math.asin(sy),
      0,
    );
  }

  vm.Quaternion _fromEuler(double x, double y, double z) {
    return vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), y) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), x) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), z);
  }

  void _reparent(Node child, Node newParent) {
    final world = child.globalTransform.clone();
    child.parent?.remove(child);
    newParent.add(child);
    final inv = vm.Matrix4.identity();
    inv.copyInverse(newParent.globalTransform);
    child.localTransform = (inv * world) as vm.Matrix4;
  }

  /// Rotates [v] by the rotation part of [m] (column-major upper 3x3).
  vm.Vector3 _rotatedBy(vm.Matrix4 m, vm.Vector3 v) {
    return vm.Vector3(
      m[0] * v.x + m[4] * v.y + m[8] * v.z,
      m[1] * v.x + m[5] * v.y + m[9] * v.z,
      m[2] * v.x + m[6] * v.y + m[10] * v.z,
    );
  }

  int _dominantAxis(vm.Vector3 v) {
    final ax = v.x.abs(), ay = v.y.abs(), az = v.z.abs();
    if (ax > ay) return ax > az ? 0 : 2;
    return ay > az ? 1 : 2;
  }

  // ---------------- gestures ----------------

  void handleDown(ui.Offset pos, ui.Size size) {
    _viewSize = size;
    _idle = 0;
    _autoTimer = 0;
    if (_twist != null) return;
    final ray = camera.screenPointToRay(pos, size);
    final hit = scene.raycast(ray);
    if (hit == null) {
      _drag = _Drag.orbit(lastX: pos.dx, lastY: pos.dy);
      return;
    }
    var node = hit.node;
    while (node.parent != null && !_cubieIndex.containsKey(node)) {
      node = node.parent!;
    }
    final cubieIdx = _cubieIndex[node];
    if (cubieIdx == null) {
      _drag = _Drag.orbit(lastX: pos.dx, lastY: pos.dy);
      return;
    }
    // Face normal into holder-local space, snapped to dominant axis.
    final inv = vm.Matrix4.identity()..copyInverse(holder.globalTransform);
    final nLocal = _rotatedBy(inv, hit.worldNormal.clone())..normalize();
    final nAxis = _dominantAxis(nLocal);
    final nVec = vm.Vector3.zero()
      ..[nAxis] = (nLocal[nAxis] >= 0 ? 1.0 : -1.0);
    final pLocal = inv.transform3(hit.worldPoint.clone());
    _drag = _Drag.twist(
      normal: nVec,
      normalAxis: nAxis,
      planePoint: pLocal,
      planeNormal: nVec,
      grid: grids[cubieIdx].clone(),
      startX: pos.dx,
      startY: pos.dy,
    )..lastX = pos.dx
     ..lastY = pos.dy;
  }

  void handleMove(ui.Offset pos) {
    final d = _drag;
    if (d == null) return;
    if (d.mode == _DragMode.orbit) {
      final dx = pos.dx - d.lastX;
      final dy = pos.dy - d.lastY;
      d.lastX = pos.dx;
      d.lastY = pos.dy;
      _yaw += dx * 0.008;
      _pitch = (_pitch + dy * 0.006).clamp(-0.9, 0.9);
      orbit.rotation =
          vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _yaw) *
          vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), _pitch);
      _idle = 0;
      return;
    }
    if (d.consumed || _twist != null) return;
    if ((pos.dx - d.startX).abs() < dragPx &&
        (pos.dy - d.startY).abs() < dragPx) {
      // Also require radial distance like the portfolio's hypot check.
      final dist = math.sqrt(
        math.pow(pos.dx - d.startX, 2) + math.pow(pos.dy - d.startY, 2),
      );
      if (dist < dragPx) return;
    }
    // Ray in holder-local space, intersect with the grab plane.
    final ray = camera.screenPointToRay(pos, _viewSize);
    final inv = vm.Matrix4.identity()..copyInverse(holder.globalTransform);
    final originL = inv.transform3(ray.origin.clone());
    final dirL = _rotatedBy(inv, ray.direction.clone())..normalize();
    final denom = dirL.dot(d.planeNormal);
    if (denom.abs() < 1e-6) return;
    final t = (d.planePoint - originL).dot(d.planeNormal) / denom;
    if (t < 0) return;
    final hitP = originL + dirL * t;
    final v = (hitP - d.planePoint)
      ..addScaled(d.planeNormal, -((hitP - d.planePoint).dot(d.planeNormal)));
    var best = 0;
    var bestVal = -1.0;
    for (var i = 0; i < 3; i++) {
      if (i == d.normalAxis) continue;
      final c = v[i].abs();
      if (c > bestVal) {
        bestVal = c;
        best = i;
      }
    }
    if (bestVal < 1e-4) return;
    final dragDir = vm.Vector3.zero()..[best] = v[best] >= 0 ? 1.0 : -1.0;
    final raw = d.normal.cross(dragDir);
    final axis = _dominantAxis(raw);
    final dir = (raw[axis] >= 0 ? 1 : -1);
    d.consumed = true;
    _triggerTwist(axis, d.grid[axis].round(), dir);
    _idle = 0;
  }

  void handleUp() {
    _drag = null;
  }
}
