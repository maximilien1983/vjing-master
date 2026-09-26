import 'package:flutter/material.dart';

/// Tokens du design « table de mixage 70's » (docs/design/DESIGN.md §3).
/// Les maquettes HTML de docs/design/screens/ font foi pour les valeurs.
abstract final class VjColors {
  static const ground = Color(0xFF0B0B0C);

  // Façade aluminium (dégradé vertical).
  static const aluTop = Color(0xFF3A3B3F);
  static const aluMid = Color(0xFF2F3034);
  static const aluBottom = Color(0xFF27282B);

  // Zones enfoncées.
  static const recessTop = Color(0xFF141416);
  static const recessBottom = Color(0xFF1B1B1E);

  // Joues en noyer (dégradé horizontal, 5 arrêts).
  static const walnut = [
    Color(0xFF22130A),
    Color(0xFF4A2B18),
    Color(0xFF5B3720),
    Color(0xFF432716),
    Color(0xFF1F1108),
  ];

  // Sérigraphie.
  static const print = Color(0xFFE9DFC7);
  static const printDim = Color(0xFFB8AD95);
  static const pointer = Color(0xFFF3EAD3);

  // LED ambrée.
  static const amberCore = Color(0xFFFFB547);
  static const amberHi = Color(0xFFFFF1C9);
  static const amberEdge = Color(0xFFD9741A);
  static const amberLabel = Color(0xFFFFC166);
  static const amberGlow = Color(0x99FFAA3C); // rgba(255,170,60,.6)
  static const amberGlowFar = Color(0x59FF8C1E); // rgba(255,140,30,.35)
  static const ledOffHi = Color(0xFF5A3D1D);
  static const ledOffLo = Color(0xFF24170A);

  // Lentilles des déclencheurs.
  static const lensOffHi = Color(0xFF4A3620);
  static const lensOffLo = Color(0xFF211608);
  static const lensText = Color(0xFFEADCC0);
  static const lensOn = [
    Color(0xFFFFF4D2),
    Color(0xFFFFC35C),
    Color(0xFFF08A1F),
    Color(0xFFC05F10),
  ];
  static const lensOnText = Color(0xFF4A2305);

  // On Air.
  static const onAirOn = [Color(0xFFFF8A66), Color(0xFFE8301E), Color(0xFFA3150C)];
  static const onAirOnText = Color(0xFFFFF3E6);
  static const onAirOff = [Color(0xFF4A1A15), Color(0xFF2A0D0A), Color(0xFF1C0806)];
  static const onAirOffText = Color(0xFFB36A5C);

  // Tubes Nixie.
  static const nixieDigit = Color(0xFFFFB566);
  static const nixieGlow = Color(0xFFFF7B1C);

  // Touches mécaniques.
  static const keyTop = Color(0xFF3F4044);
  static const keyMid = Color(0xFF323337);
  static const keyBottom = Color(0xFF2A2B2E);
  static const keyEdge = Color(0xFF121214);
}

/// Styles de texte (Barlow Condensed embarquée ; letterSpacing en pt,
/// calculé depuis les em des maquettes : em × taille).
abstract final class VjText {
  static const _family = 'Barlow Condensed';

  static const sectionTitle = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 11 * .26,
    color: VjColors.print,
    height: 14 / 11,
  );

  static const crankLabel = TextStyle(
    fontFamily: _family,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: VjColors.printDim,
  );

  static const lensLabel = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 15 * .16,
    color: VjColors.lensText,
  );

  static const keyLabel = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 12 * .24,
    color: VjColors.print,
  );

  static const hint = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 11 * .14,
    color: VjColors.printDim,
  );

  static const nixie = TextStyle(
    fontFamily: _family,
    fontSize: 38,
    fontWeight: FontWeight.w300,
    color: VjColors.nixieDigit,
    height: 1,
  );

  static const wordmark = TextStyle(
    fontFamily: 'Allura',
    fontSize: 25,
    fontWeight: FontWeight.w400,
  );
}

/// Rayons et dimensions récurrentes.
abstract final class VjDims {
  static const cheekWidth = 36.0;
  static const refSize = Size(844, 390);
  static const keyRadius = 6.0;
  static const padRadius = 9.0;
  static const lensRadius = 4.0;
  static const thumbRadius = 5.0;
  static const recessRadius = 8.0;
  static const drawerRadius = 16.0;
  static const minTouch = 48.0;
}
