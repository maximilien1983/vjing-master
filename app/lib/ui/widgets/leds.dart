import 'package:flutter/material.dart';

import '../../theme/vj_tokens.dart';

/// LED ronde ambrée (allumée : dégradé radial + halo ; éteinte : creuse).
class AmberLed extends StatelessWidget {
  final double size;
  final bool on;
  /// Intensité 0-1 quand allumée (LED tempo : fondu après le temps).
  final double intensity;
  const AmberLed({super.key, required this.on, this.size = 7, this.intensity = 1});

  @override
  Widget build(BuildContext context) {
    if (!on || intensity <= 0) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-.3, -.3),
            colors: [VjColors.ledOffHi, VjColors.ledOffLo],
            stops: [0, .75],
          ),
          boxShadow: [
            BoxShadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Color(0xCC000000),
                blurStyle: BlurStyle.inner),
          ],
        ),
      );
    }
    final a = intensity.clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.3, -.3),
          colors: [
            Color.lerp(VjColors.ledOffHi, VjColors.amberHi, a)!,
            Color.lerp(VjColors.ledOffHi, VjColors.amberCore, a)!,
            Color.lerp(VjColors.ledOffLo, VjColors.amberEdge, a)!,
          ],
          stops: const [0, .42, .85],
        ),
        boxShadow: [
          BoxShadow(
              blurRadius: 6,
              spreadRadius: 2,
              color: VjColors.amberGlow.withValues(alpha: .6 * a)),
          BoxShadow(
              blurRadius: 14,
              color: VjColors.amberGlowFar.withValues(alpha: .35 * a)),
        ],
      ),
    );
  }
}

/// Voyant rectangulaire 14 × 8 des touches Suivant / Garder.
class IndicatorLamp extends StatelessWidget {
  final bool on;
  const IndicatorLamp({super.key, required this.on});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 8,
      decoration: on
          ? const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              gradient: RadialGradient(
                center: Alignment(0, -.2),
                radius: 1.2,
                colors: [VjColors.amberHi, VjColors.amberCore, Color(0xFFE07A1A)],
                stops: [0, .55, 1],
              ),
              boxShadow: [
                BoxShadow(blurRadius: 6, spreadRadius: 2, color: VjColors.amberGlow),
                BoxShadow(blurRadius: 14, color: VjColors.amberGlowFar),
              ],
            )
          : BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              color: const Color(0xFF33240F),
              boxShadow: [
                const BoxShadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Color(0xCC000000),
                    blurStyle: BlurStyle.inner),
                BoxShadow(
                    offset: const Offset(0, 1),
                    color: Colors.white.withValues(alpha: .06)),
              ],
            ),
    );
  }
}
