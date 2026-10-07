import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vj_tokens.dart';
import 'leds.dart';

/// Touche mécanique rectangulaire (« tkey » des maquettes) : relief 3 pt,
/// s'enfonce de 2 pt quand elle est active ou pressée.
class MechKey extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool down; // état enfoncé permanent (bascule active)
  final double width;
  final double height;
  final String? semanticsLabel;
  const MechKey({
    super.key,
    required this.child,
    this.onTap,
    this.down = false,
    required this.width,
    this.height = 48,
    this.semanticsLabel,
  });

  @override
  State<MechKey> createState() => _MechKeyState();
}

class _MechKeyState extends State<MechKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final down = widget.down || _pressed;
    return Semantics(
      label: widget.semanticsLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          // +2 de marge pour le débattement vertical.
          height: widget.height + 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            width: widget.width,
            height: widget.height,
            margin: EdgeInsets.only(top: down ? 2 : 0, bottom: down ? 0 : 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VjDims.keyRadius),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [VjColors.keyTop, VjColors.keyMid, VjColors.keyBottom],
                stops: [0, .55, 1],
              ),
              boxShadow: [
                BoxShadow(
                    offset: Offset(0, down ? 1 : 3), color: VjColors.keyEdge),
                BoxShadow(
                    offset: Offset(0, down ? 2 : 5),
                    blurRadius: down ? 4 : 8,
                    color: Colors.black.withValues(alpha: .5)),
                BoxShadow(
                    offset: const Offset(0, 1),
                    color: Colors.white.withValues(alpha: down ? .1 : .16),
                    blurStyle: BlurStyle.inner),
              ],
            ),
            foregroundDecoration: down && widget.down
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(VjDims.keyRadius),
                    boxShadow: [
                      BoxShadow(
                          blurRadius: 18,
                          color: const Color(0xFFFFA03C).withValues(alpha: .08),
                          blurStyle: BlurStyle.inner),
                    ],
                  )
                : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Touche Suivant / Garder : voyant + libellé (135 × 48).
class IndicatorKey extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final double width;
  const IndicatorKey({
    super.key,
    required this.label,
    this.on = false,
    this.onTap,
    this.width = 135,
  });

  @override
  Widget build(BuildContext context) {
    return MechKey(
      width: width,
      down: on,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      semanticsLabel: on ? '$label, enfoncé' : label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IndicatorLamp(on: on),
            const SizedBox(width: 12),
            Text(label.toUpperCase(), style: VjText.keyLabel),
          ],
        ),
      ),
    );
  }
}

/// Bouton caméra : affiche/masque la caméra de l'appareil en surimpression
/// du fond (webcam en préviz PC). Enfoncé et ambré tant qu'elle est affichée.
class CameraButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  final double size;
  const CameraButton(
      {super.key, required this.active, this.onTap, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return MechKey(
      width: size,
      height: size,
      down: active,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      semanticsLabel:
          active ? 'Masquer la caméra' : 'Afficher la caméra',
      child: Center(
        child: Icon(active ? Icons.videocam : Icons.videocam_outlined,
            size: size * 0.54,
            color: active ? VjColors.amberLabel : VjColors.print),
      ),
    );
  }
}

/// Bouton de diffusion 48 × 48 : icône TV + triangle, crème ou ambrée.
class CastButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  const CastButton({super.key, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return MechKey(
      width: 48,
      height: 48,
      onTap: onTap,
      semanticsLabel:
          active ? 'Diffusion vers la TV (connectée)' : 'Diffuser vers la TV',
      child: Center(
        child: CustomPaint(
          size: const Size(24, 24),
          painter: _CastIconPainter(
              active ? VjColors.amberLabel : VjColors.print, active),
        ),
      ),
    );
  }
}

class _CastIconPainter extends CustomPainter {
  final Color color;
  final bool glow;
  _CastIconPainter(this.color, this.glow);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (glow) {
      stroke.maskFilter = null;
      canvas.drawPath(
          _tvPath(s),
          Paint()
            ..color = color.withValues(alpha: .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7 * s
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    canvas.drawPath(_tvPath(s), stroke);
    // Triangle (pied / signal) rempli.
    final tri = Path()
      ..moveTo(12 * s, 14 * s)
      ..lineTo(17 * s, 20 * s)
      ..lineTo(7 * s, 20 * s)
      ..close();
    canvas.drawPath(tri, Paint()..color = color);
  }

  Path _tvPath(double s) => Path()
    ..moveTo(7 * s, 17 * s)
    ..lineTo(5 * s, 17 * s)
    ..arcToPoint(Offset(3 * s, 15 * s), radius: Radius.circular(2 * s))
    ..lineTo(3 * s, 6 * s)
    ..arcToPoint(Offset(5 * s, 4 * s), radius: Radius.circular(2 * s))
    ..lineTo(19 * s, 4 * s)
    ..arcToPoint(Offset(21 * s, 6 * s), radius: Radius.circular(2 * s))
    ..lineTo(21 * s, 15 * s)
    ..arcToPoint(Offset(19 * s, 17 * s), radius: Radius.circular(2 * s))
    ..lineTo(17 * s, 17 * s);

  @override
  bool shouldRepaint(covariant _CastIconPainter old) =>
      old.color != color || old.glow != glow;
}
