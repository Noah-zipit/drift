// Vibrant, glossy visual language: deep indigo stage, juicy candy blocks.
// Inspired by the classic block-puzzle look: bright gloss highlights,
// rich saturated colours, white text. No green-dominant UI.

import 'package:flutter/material.dart';

class Palette {
  Palette._();

  /// App background: deep indigo blue.
  static const Color background = Color(0xFF2D368B);

  /// Board panel surface: darker navy.
  static const Color boardSurface = Color(0xFF222A66);

  /// Empty board cells: a touch lighter than the panel, so the grid reads.
  static const Color emptyCell = Color(0xFF2C3579);

  /// Tray panel surface: indigo between background and board.
  static const Color traySurface = Color(0xFF28317C);

  /// Primary text: white.
  static const Color ink = Color(0xFFFFFFFF);

  /// Secondary text: soft translucent white.
  static const Color inkSoft = Color(0xB3FFFFFF);

  /// Crown / best-score gold.
  static const Color crown = Color(0xFFFFC93C);

  /// Primary button colour: juicy bright orange.
  static const Color accent = Color(0xFFF5821F);

  /// Deep navy for text sitting on bright buttons.
  static const Color onAccent = Color(0xFF232A68);

  /// Vibrant glossy piece colours: bright orange, golden yellow,
  /// vivid purple, coral red, teal, hot pink, sky blue, lime.
  /// A single lime is fine; the UI itself stays indigo, never green.
  static const List<Color> pieces = [
    Color(0xFFF5821F), // bright orange
    Color(0xFFFFC21A), // golden yellow
    Color(0xFF9B2FD6), // vivid purple
    Color(0xFFF04E45), // coral red
    Color(0xFF22B8B8), // teal
    Color(0xFFF5429B), // hot pink
    Color(0xFF3FA9F5), // sky blue
    Color(0xFFA6D933), // lime
  ];

  /// Strong milky gloss highlight for the top of each block.
  static Color highlight(Color base) =>
      Color.lerp(const Color(0xFFFFFFFF), base, 0.35)!;

  /// Darkened shade for the bottom of each block (glossy depth).
  static Color shade(Color base) =>
      Color.lerp(base, const Color(0xFF000000), 0.22)!;

  /// Card / overlay surfaces: lighter indigo.
  static const Color card = Color(0xFF3A4496);

  /// Dark scrim behind modal overlays.
  static const Color scrim = Color(0xB31A1F4D);
}
