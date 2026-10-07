import 'package:flutter/material.dart';

import '../../theme/vj_tokens.dart';
import '../sprites.dart';

/// Lampe On Air 68 × 38 : rouge vif quand une TV reçoit le flux, brique
/// éteinte sinon. Le rouge est réservé à cette lampe (DESIGN.md §3).
/// Fenêtre et cadre métal : sprites ; le libellé reste dessiné.
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
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          image: DecorationImage(
            image: on ? VjSprites.onairOn : VjSprites.onairOff,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
          boxShadow: on
              ? [
                  BoxShadow(
                      blurRadius: 16,
                      spreadRadius: 2,
                      color: const Color(0xFFFF3C28).withValues(alpha: .45)),
                  BoxShadow(
                      blurRadius: 40,
                      color: const Color(0xFFFF2814).withValues(alpha: .22)),
                ]
              : [
                  BoxShadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: .6)),
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
                        color: const Color(0xFFFFDCC8).withValues(alpha: .9)),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
