import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/vj_tokens.dart';
import '../sprites.dart';
import 'leds.dart';

/// Afficheur BPM : 3 tubes Nixie. `bpm` ≤ 0 : tubes éteints (fantômes seuls).
class NixieDisplay extends StatelessWidget {
  final double bpm;
  final Size tubeSize; // 34 × 46 console, 22 × 32 plaque locale
  final double fontSize;
  const NixieDisplay({
    super.key,
    required this.bpm,
    this.tubeSize = const Size(34, 46),
    this.fontSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    final text = bpm > 0 ? bpm.round().toString().padLeft(3, ' ') : '   ';
    return Semantics(
      label: bpm > 0 ? 'Tempo : ${bpm.round()} BPM' : 'Tempo inconnu',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: tubeSize.width > 30 ? 5 : 3),
            _NixieTube(
              digit: text[i] == ' ' ? null : text[i],
              size: tubeSize,
              fontSize: fontSize,
            ),
          ],
        ],
      ),
    );
  }
}

class _NixieTube extends StatelessWidget {
  final String? digit;
  final Size size;
  final double fontSize;
  const _NixieTube({required this.digit, required this.size, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    // Verre, culot et grille nid d'abeille : sprite du tube (vue de face) ;
    // le halo et les chiffres restent dessinés par le code.
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: Image(
                image: VjSprites.nixieOff,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            // Chiffre fantôme.
            Text('8',
                style: TextStyle(
                  fontFamily: 'Barlow Condensed',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w300,
                  height: 1,
                  color: const Color(0xFFFFAA64).withValues(alpha: .07),
                )),
            if (digit != null)
              Text(
                digit!,
                style: TextStyle(
                  fontFamily: 'Barlow Condensed',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w300,
                  height: 1,
                  color: VjColors.nixieDigit,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
                    const Shadow(blurRadius: 2, color: Color(0xFFFFD9A0)),
                    const Shadow(blurRadius: 6, color: VjColors.nixieGlow),
                    Shadow(
                        blurRadius: 14,
                        color: const Color(0xFFFF5A00).withValues(alpha: .75)),
                  ],
                ),
              ),
          ],
      ),
    );
  }
}

/// LED tempo : allumée franchement sur le temps, éteinte à ~20 % de la
/// période, fondu jusqu'à 45 % (DESIGN.md §6). Calée sur l'horloge de
/// détection via [beatPhase] (phase du temps courant, [0,1)).
class TempoLed extends StatefulWidget {
  final double Function() beatPhase;
  final bool active; // faux tant qu'aucun tempo n'est verrouillé
  final double size;
  const TempoLed({
    super.key,
    required this.beatPhase,
    required this.active,
    this.size = 10,
  });

  @override
  State<TempoLed> createState() => _TempoLedState();
}

/// Profil d'intensité de la LED tempo : 0-22 % de période à pleine
/// intensité, fondu de 22 à 45 %, éteinte ensuite.
double tempoLedIntensity(double phase) {
  final p = phase % 1;
  if (p < .22) return 1;
  if (p < .45) return 1 - (p - .22) / .23;
  return 0;
}

class _TempoLedState extends State<TempoLed>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _intensity = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final v = widget.active ? tempoLedIntensity(widget.beatPhase()) : 0.0;
      if ((v - _intensity).abs() > .01) setState(() => _intensity = v);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AmberLed(on: _intensity > 0, intensity: _intensity, size: widget.size);
  }
}
