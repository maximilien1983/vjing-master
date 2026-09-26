import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vj_tokens.dart';

/// Bouton Lancer de l'écran de démarrage : lunette crantée 116 pt,
/// anneau ambré, chapeau métal avec symbole marche.
class PowerButton extends StatefulWidget {
  final VoidCallback onPressed;
  const PowerButton({super.key, required this.onPressed});

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Lancer',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? .97 : 1,
          duration: const Duration(milliseconds: 80),
          child: CustomPaint(
            size: const Size(116, 116),
            painter: _PowerPainter(),
          ),
        ),
      ),
    );
  }
}

class _PowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // Ombre portée.
    canvas.drawCircle(
      c + const Offset(0, 12),
      size.width / 2 - 2,
      Paint()
        ..color = Colors.black.withValues(alpha: .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Lunette crantée (repeating-conic 3°/3°).
    final colors = <Color>[];
    final stops = <double>[];
    const sectors = 60;
    for (var i = 0; i < sectors; i++) {
      final t0 = i / sectors;
      final t1 = (i + .5) / sectors;
      colors.addAll([
        const Color(0xFF8C8E92),
        const Color(0xFF8C8E92),
        const Color(0xFF5B5D61),
        const Color(0xFF5B5D61)
      ]);
      stops.addAll([t0, t1, t1, (i + 1) / sectors]);
    }
    canvas.drawCircle(
      c,
      size.width / 2,
      Paint()
        ..shader = SweepGradient(colors: colors, stops: stops)
            .createShader(Rect.fromCircle(center: c, radius: size.width / 2)),
    );
    // Fond sombre + anneau ambré lumineux.
    canvas.drawCircle(c, 48, Paint()..color = const Color(0xFF1A0F05));
    canvas.drawCircle(
      c,
      48,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFB046).withValues(alpha: .9),
    );
    canvas.drawCircle(
      c,
      48,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFFF9628).withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Chapeau.
    canvas.drawCircle(
      c,
      43,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.2, -.45),
          colors: [const Color(0xFF4C4D52), const Color(0xFF1D1E21)],
          stops: const [0, .72],
        ).createShader(Rect.fromCircle(center: c, radius: 43)),
    );
    canvas.drawCircle(
      c,
      43,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: .15),
    );
    // Symbole marche : trait vertical + arc.
    final sym = Paint()
      ..color = const Color(0xFFF1E7CF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(0, -13), c + const Offset(0, -1), sym);
    canvas.drawArc(Rect.fromCircle(center: c + const Offset(0, -1), radius: 12),
        -math.pi / 2 + .6, 2 * math.pi - 1.2, false, sym);
  }

  @override
  bool shouldRepaint(covariant _PowerPainter old) => false;
}

/// Voyant Prêt au-dessus du bouton Lancer.
class ReadyLamp extends StatelessWidget {
  final bool on;
  const ReadyLamp({super.key, required this.on});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(30 * math.pi / 180),
              colors: [
                Color(0xFF6A6C70), Color(0xFFC2C4C7), Color(0xFF5C5E62),
                Color(0xFFB3B5B8), Color(0xFF6A6C70),
              ],
              stops: [0, .2, .45, .7, 1],
            ),
            boxShadow: [
              BoxShadow(offset: Offset(0, 2), blurRadius: 3, color: Color(0xB3000000)),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: on
                  ? const RadialGradient(
                      center: Alignment(-.24, -.36),
                      colors: [Color(0xFFFFF3CC), Color(0xFFFFBF55), Color(0xFFD9701A)],
                      stops: [0, .35, .8],
                    )
                  : const RadialGradient(
                      center: Alignment(-.3, -.3),
                      colors: [VjColors.ledOffHi, VjColors.ledOffLo],
                    ),
              boxShadow: on
                  ? [
                      BoxShadow(
                          blurRadius: 8,
                          spreadRadius: 2,
                          color: const Color(0xFFFFA032).withValues(alpha: .55)),
                      BoxShadow(
                          blurRadius: 18,
                          color: const Color(0xFFFF821E).withValues(alpha: .3)),
                    ]
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('PRÊT',
            style: VjText.sectionTitle.copyWith(letterSpacing: 11 * .28)),
      ],
    );
  }
}
