import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vj_tokens.dart';

/// Les 7 effets de la console (id protocole, libellé, couleur de diode).
/// `flash` est armé sur le prochain temps par le moteur ; les autres sont
/// maintenables : tap = une mesure complète, maintien = jusqu'au relâchement
/// (voir renderer/PROTOCOL.md).
typedef FxDef = ({String id, String label, Color color});

const List<FxDef> fxDefs = [
  (id: 'flash', label: 'FLASH', color: Color(0xFFFFB13D)),
  (id: 'strobe', label: 'STROBE', color: Color(0xFFEAF4FF)),
  (id: 'negative', label: 'NÉGATIF', color: Color(0xFFB06CFF)),
  (id: 'zoom', label: 'ZOOM', color: Color(0xFF3FD9E8)),
  (id: 'shake', label: 'SHAKE', color: Color(0xFF5BE06A)),
  (id: 'echo', label: 'ECHO', color: Color(0xFFFF5FA8)),
  (id: 'rewind', label: 'REWIND', color: Color(0xFFFF4A3C)),
];

/// Petit bouton-poussoir rond façon console 70s : couronne métal moletée,
/// capuchon bakélite bombé qui s'enfonce, diode colorée au-dessus, libellé
/// gravé dessous. Envoie on à l'appui et off au relâchement ; la diode reste
/// allumée le temps du burst (une mesure) après un tap.
class FxButton extends StatefulWidget {
  final String label;
  final Color diode;
  final double diameter; // 42 console, 36 tiroir
  final VoidCallback onDown;
  final VoidCallback onUp;

  /// Durée du voyant après un tap (≈ une mesure, calculée par l'appelant).
  final Duration Function()? litFor;

  const FxButton({
    super.key,
    required this.label,
    required this.diode,
    required this.onDown,
    required this.onUp,
    this.diameter = 42,
    this.litFor,
  });

  @override
  State<FxButton> createState() => _FxButtonState();
}

class _FxButtonState extends State<FxButton> {
  bool _held = false;
  bool _lit = false;
  Timer? _off;

  // Couronne moletée : 56 facettes claires/sombres alternées (métal tourné).
  static final _knurl = () {
    final colors = <Color>[];
    final stops = <double>[];
    const steps = 28;
    for (var i = 0; i < steps; i++) {
      final t0 = i / steps;
      final t1 = (i + .5) / steps;
      colors.addAll(const [
        Color(0xFF6E7074),
        Color(0xFF6E7074),
        Color(0xFF26272A),
        Color(0xFF26272A),
      ]);
      stops.addAll([t0, t1, t1, (i + 1) / steps]);
    }
    return SweepGradient(colors: colors, stops: stops);
  }();

  @override
  void dispose() {
    _off?.cancel();
    super.dispose();
  }

  void _press() {
    HapticFeedback.lightImpact();
    _off?.cancel();
    setState(() {
      _held = true;
      _lit = true;
    });
    widget.onDown();
  }

  void _release() {
    if (!_held) return;
    setState(() => _held = false);
    widget.onUp();
    _off?.cancel();
    _off = Timer(
        widget.litFor?.call() ?? const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _lit = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    return Semantics(
      label: _lit ? '${widget.label}, actif' : widget.label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Diode(color: widget.diode, on: _lit),
            const SizedBox(height: 5),
            _button(d),
            const SizedBox(height: 5),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Barlow Condensed',
                fontSize: d > 40 ? 9.5 : 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: VjColors.printDim,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(double d) {
    final down = _held;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Couronne métal moletée, posée sur la façade.
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _knurl,
              boxShadow: [
                BoxShadow(
                    offset: const Offset(0, 3),
                    blurRadius: 7,
                    color: Colors.black.withValues(alpha: .55)),
                BoxShadow(
                    offset: const Offset(0, -1),
                    blurRadius: 1,
                    color: Colors.white.withValues(alpha: .10)),
              ],
            ),
          ),
          // Gorge sombre entre la couronne et le capuchon.
          Container(
            width: d * .78,
            height: d * .78,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF0B0B0D)),
          ),
          // Capuchon bakélite bombé, s'enfonce à l'appui.
          AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            width: d * .66,
            height: d * .66,
            transform: Matrix4.translationValues(0, down ? 1.5 : 0, 0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-.35, -.42),
                radius: 1.15,
                colors: down
                    ? const [Color(0xFF39352F), Color(0xFF171513)]
                    : const [Color(0xFF4B463F), Color(0xFF1D1A17)],
              ),
              boxShadow: [
                BoxShadow(
                    offset: Offset(0, down ? 1 : 2.5),
                    blurRadius: down ? 2 : 5,
                    color: Colors.black.withValues(alpha: .65)),
                BoxShadow(
                    offset: const Offset(0, 1),
                    color: Colors.white.withValues(alpha: down ? .10 : .16),
                    blurStyle: BlurStyle.inner),
              ],
            ),
          ),
          // Reflet spéculaire en croissant, en haut du capuchon.
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0, -.44),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 70),
                width: d * .3,
                height: d * .1,
                transform:
                    Matrix4.translationValues(0, down ? 1.5 : 0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(d),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: down ? .18 : .30),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diode témoin : collerette métal, jewel coloré qui s'allume avec halo.
class _Diode extends StatelessWidget {
  final Color color;
  final bool on;
  const _Diode({required this.color, required this.on});

  @override
  Widget build(BuildContext context) {
    final litHi = Color.lerp(color, Colors.white, .55)!;
    final offHi = Color.lerp(color, Colors.black, .62)!;
    final offLo = Color.lerp(color, Colors.black, .85)!;
    return Container(
      width: 13,
      height: 13,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF55575B), Color(0xFF1A1B1D)],
        ),
        boxShadow: const [
          BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0xCC000000),
              blurStyle: BlurStyle.inner),
        ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-.3, -.35),
            colors: on ? [litHi, color] : [offHi, offLo],
          ),
          boxShadow: on
              ? [
                  BoxShadow(
                      blurRadius: 9,
                      spreadRadius: 1,
                      color: color.withValues(alpha: .8)),
                  BoxShadow(
                      blurRadius: 20, color: color.withValues(alpha: .4)),
                ]
              : const [
                  BoxShadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Color(0x99000000),
                      blurStyle: BlurStyle.inner),
                ],
        ),
      ),
    );
  }
}
