import 'package:flutter/material.dart';

import '../../theme/vj_tokens.dart';

/// Lampe On Air 68 × 38 : rouge vif quand une TV reçoit le flux, brique
/// éteinte sinon. Le rouge est réservé à cette lampe (DESIGN.md §3).
class OnAirLamp extends StatelessWidget {
  final bool on;
  const OnAirLamp({super.key, required this.on});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: on ? 'On Air : diffusion en cours' : 'On Air éteint',
      child: Container(
        width: 68,
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0B), Color(0xFF232326)],
          ),
          boxShadow: [
            BoxShadow(
                offset: const Offset(0, 1),
                color: Colors.white.withValues(alpha: .08)),
            const BoxShadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black,
                blurStyle: BlurStyle.inner),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: on
                ? const RadialGradient(
                    center: Alignment(0, -.1),
                    radius: 1.1,
                    colors: VjColors.onAirOn,
                    stops: [0, .55, 1],
                  )
                : const RadialGradient(
                    center: Alignment(0, -.3),
                    radius: 1.2,
                    colors: VjColors.onAirOff,
                    stops: [0, .7, 1],
                  ),
            boxShadow: on
                ? [
                    BoxShadow(
                        blurRadius: 16,
                        spreadRadius: 2,
                        color: const Color(0xFFFF3C28).withValues(alpha: .55)),
                    BoxShadow(
                        blurRadius: 40,
                        color: const Color(0xFFFF2814).withValues(alpha: .28)),
                  ]
                : const [
                    BoxShadow(
                        offset: Offset(0, 2),
                        blurRadius: 5,
                        color: Color(0x99000000),
                        blurStyle: BlurStyle.inner),
                  ],
          ),
          child: Text(
            'ON AIR',
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 14 * .14,
              color: on ? VjColors.onAirOnText : VjColors.onAirOffText,
              shadows: on
                  ? [
                      Shadow(
                          blurRadius: 6,
                          color:
                              const Color(0xFFFFDCC8).withValues(alpha: .9)),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
