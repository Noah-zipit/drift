// Juicy-but-smooth visual effects: pop clears with a staggered sweep,
// scale-in combo labels, modest sparkle bursts. Lively, never a casino
// explosion. No screen shake.

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../theme/palette.dart';

// ---------------------------------------------------------------- easing

/// Clamp to 0..1 while staying a `double` (`num.clamp` would widen to `num`).
double clamp01(double t) => t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);

double easeOutCubic(double t) {
  final u = 1.0 - clamp01(t);
  return 1.0 - u * u * u;
}

double easeInCubic(double t) {
  final k = clamp01(t);
  return k * k * k;
}

double easeInOutCubic(double t) {
  final k = clamp01(t);
  if (k < 0.5) {
    return 4.0 * k * k * k;
  }
  final u = 1.0 - k;
  return 1.0 - 4.0 * u * u * u;
}

double easeOutSine(double t) {
  return sin(clamp01(t) * pi / 2.0);
}

/// Overshoot easing for the clear pop and combo scale-in.
double easeOutBack(double t) {
  final k = clamp01(t);
  const c1 = 1.70158;
  const c3 = c1 + 1.0;
  final u = k - 1.0;
  return 1.0 + c3 * u * u * u + c1 * u * u;
}

// ------------------------------------------------------------ score layer

/// Hosts transient effects (score popups, combo labels, sparkles).
/// Added once to the game; effects add/remove themselves.
class ScoreLayer extends Component {
  void popup(String text, Vector2 at) {
    add(ScorePopup(text, at));
  }

  void combo(String text, Vector2 at) {
    add(ComboLabel(text, at));
  }

  /// A modest burst of sparkles over cleared cells: three per cell,
  /// capped at 72, quick rise and fade. Juicy, not blinding.
  void softSparkles(List<Vector2> centres, List<Color> colours, Random rng) {
    var spawned = 0;
    for (var i = 0; i < centres.length && spawned < 72; i++) {
      for (var j = 0; j < 3 && spawned < 72; j++) {
        add(SoftSparkle(centres[i], colours[i % colours.length], rng));
        spawned++;
      }
    }
  }
}

/// A "+N" that pops in with a little overshoot, floats up and fades.
class ScorePopup extends PositionComponent {
  ScorePopup(this.text, Vector2 at) {
    position = at.clone();
    anchor = Anchor.center;
    size = Vector2(160, 48);
    priority = 30;
  }

  final String text;
  double _t = 0.0;
  static const double _duration = 1.0;

  @override
  void update(double dt) {
    _t += dt;
    position.y -= 44.0 * dt; // gentle rise
    if (_t >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final k = clamp01(_t / _duration);
    final alpha = k < 0.15 ? k / 0.15 : 1.0 - (k - 0.15) / 0.85;
    final scale = k < 0.3 ? 0.6 + 0.4 * easeOutBack(k / 0.3) : 1.0;
    final paint = TextPaint(
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: Palette.ink.withValues(alpha: alpha),
      ),
    );
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scale);
    canvas.translate(-size.x / 2, -size.y / 2);
    paint.render(canvas, text, size / 2, anchor: Anchor.center);
    canvas.restore();
  }
}

/// A punchy combo label ("DOUBLE!") that scales in with overshoot,
// holds, then fades out.
class ComboLabel extends PositionComponent {
  ComboLabel(String text, Vector2 at)
      : text = text.toUpperCase().replaceAll(' CLEAR', '!') {
    position = at.clone();
    anchor = Anchor.center;
    size = Vector2(320, 56);
    priority = 31;
  }

  final String text;
  double _t = 0.0;
  static const double _duration = 1.4;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final k = clamp01(_t / _duration);
    double alpha;
    if (k < 0.12) {
      alpha = k / 0.12;
    } else if (k > 0.7) {
      alpha = 1.0 - (k - 0.7) / 0.3;
    } else {
      alpha = 1.0;
    }
    final scale = k < 0.35 ? 0.5 + 0.5 * easeOutBack(k / 0.35) : 1.0;
    final paint = TextPaint(
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.0,
        color: Palette.crown.withValues(alpha: alpha),
      ),
    );
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scale);
    canvas.translate(-size.x / 2, -size.y / 2);
    paint.render(canvas, text, size / 2, anchor: Anchor.center);
    canvas.restore();
  }
}

/// A single sparkle that bursts outward, rises and dissolves.
class SoftSparkle extends PositionComponent {
  SoftSparkle(Vector2 at, Color colour, Random rng) {
    position = at.clone();
    anchor = Anchor.center;
    size = Vector2.all(14);
    priority = 29;
    _colour = colour;
    _radius = 3.0 + rng.nextDouble() * 3.0;
    _life = 0.7 + rng.nextDouble() * 0.5;
    final angle = rng.nextDouble() * 2.0 * pi;
    final speed = 40.0 + rng.nextDouble() * 70.0;
    _velocity = Vector2(
      cos(angle) * speed,
      sin(angle) * speed - 40.0,
    );
  }

  late final Color _colour;
  late final double _radius;
  late final double _life;
  late final Vector2 _velocity;
  double _t = 0.0;

  @override
  void update(double dt) {
    _t += dt;
    position.add(_velocity * dt);
    if (_t >= _life) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final k = clamp01(_t / _life);
    final alpha = (k < 0.2 ? k / 0.2 : 1.0 - (k - 0.2) / 0.8) * 0.55;
    final radius = _radius * (1.0 - 0.4 * k);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = _colour.withValues(alpha: alpha),
    );
  }
}
