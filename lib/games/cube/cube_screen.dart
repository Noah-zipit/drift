// Rubik's cube screen: the floating playable cube, nothing else.
// The Android system back gesture returns to the arcade menu.

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';

import '../../arcade/arcade_menu.dart';
import 'cube_controller.dart';

class CubeScreen extends StatefulWidget {
  const CubeScreen({super.key});

  @override
  State<CubeScreen> createState() => _CubeScreenState();
}

class _CubeScreenState extends State<CubeScreen> {
  final _controller = CubeController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcadePalette.abyss,
      body: _ready
          ? LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) =>
                      _controller.handleDown(d.localPosition, size),
                  onPanUpdate: (d) => _controller.handleMove(d.localPosition),
                  onPanEnd: (_) => _controller.handleUp(),
                  onPanCancel: () => _controller.handleUp(),
                  child: SceneView(
                    _controller.scene,
                    camera: _controller.camera,
                    onTick: _controller.onTick,
                  ),
                );
              },
            )
          : const SizedBox.expand(),
    );
  }
}
