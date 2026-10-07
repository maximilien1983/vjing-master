import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vj_tokens.dart';
import '../sprites.dart';

/// Angles des 6 crans, en degrés depuis le haut (0° en haut, sens horaire).
const rotaryAngles = [-150.0, -90.0, -30.0, 30.0, 90.0, 150.0];

/// Cran le plus proche d'un angle continu (pour l'aimantation du geste).
int nearestNotch(double angleDeg) {
  var a = angleDeg % 360;
  if (a > 180) a -= 360;
  if (a < -180) a += 360;
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < rotaryAngles.length; i++) {
    final d = (a - rotaryAngles[i]).abs();
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

/// Géométrie d'un rotacteur (valeurs des maquettes).
class RotaryGeometry {
  final Size size;
  final double knobDiameter;
  final Offset center;
  final double ledRadius; // distance centre -> LED / point gravé
  final double tickR1, tickR2; // trait de repère
  final double labelSideDx; // |dx| des libellés latéraux (±90°)
  final double labelDiagDx; // |dx| des libellés diagonaux
  final double labelAboveDy, labelBelowDy; // baseline des libellés hauts/bas
  final double labelFontSize;
  final bool showLabels;

  const RotaryGeometry({
    required this.size,
    required this.knobDiameter,
    required this.center,
    required this.ledRadius,
    required this.tickR1,
    required this.tickR2,
    this.labelSideDx = 0,
    this.labelDiagDx = 0,
    this.labelAboveDy = 0,
    this.labelBelowDy = 0,
    this.labelFontSize = 10,
    this.showLabels = true,
  });

  /// Démarrage : cadran 180 × 116, bouton 72.
  static const start = RotaryGeometry(
    size: Size(180, 116),
    knobDiameter: 72,
    center: Offset(90, 58),
    ledRadius: 49,
    tickR1: 40.5,
    tickR2: 46.5,
    labelSideDx: 56,
    labelDiagDx: 28,
    labelAboveDy: -45,
    labelBelowDy: 52,
    labelFontSize: 10.5,
  );

  /// Console : cadran 156 × 106, bouton 60.
  static const console = RotaryGeometry(
    size: Size(156, 106),
    knobDiameter: 60,
    center: Offset(76, 50),
    ledRadius: 41,
    tickR1: 32,
    tickR2: 38,
    labelSideDx: 48,
    labelDiagDx: 24,
    labelAboveDy: -38,
    labelBelowDy: 45,
    labelFontSize: 9.5,
  );

  /// Tiroir du mode local : 136 × 88, bouton 48. Libellés des 6 crans autour
  /// du bouton (demande utilisateur 2026-10-02 : on tournait à l'aveugle),
  /// en plus de la fenêtre ambrée sous le bouton.
  static const compact = RotaryGeometry(
    size: Size(136, 88),
    knobDiameter: 48,
    center: Offset(68, 44),
    ledRadius: 34,
    tickR1: 27,
    tickR2: 31,
    labelSideDx: 44,
    labelDiagDx: 26,
    labelAboveDy: -36,
    labelBelowDy: 42,
    labelFontSize: 7.5,
  );
}

/// Rotacteur 6 crans : glisser en rotation avec aimantation, ou toucher un
/// libellé. Clic haptique à chaque cran.
class RotarySelector extends StatefulWidget {
  final RotaryGeometry geometry;
  final List<String> labels; // 6, dans l'ordre des angles
  final int selected;
  final ValueChanged<int> onChanged;
  final String semanticsLabel; // « Style », « Univers »
  const RotarySelector({
    super.key,
    required this.geometry,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.semanticsLabel,
  }) : assert(labels.length == 6);

  @override
  State<RotarySelector> createState() => _RotarySelectorState();
}

class _RotarySelectorState extends State<RotarySelector>
    with SingleTickerProviderStateMixin {
  double? _dragAngle;

  /// Le bouton tourne physiquement d'un cran à l'autre (pas de saut) :
  /// l'angle affiché suit l'angle du cran choisi avec une courte animation.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late Animation<double> _angle = AlwaysStoppedAnimation(
    rotaryAngles[widget.selected],
  );

  @override
  void didUpdateWidget(covariant RotarySelector old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _angle = Tween(
        begin: _angle.value,
        end: rotaryAngles[widget.selected],
      ).animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutCubic));
      _spin.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  double _angleAt(Offset local) {
    final d = local - widget.geometry.center;
    return math.atan2(d.dx, -d.dy) * 180 / math.pi;
  }

  void _select(int i) {
    if (i == widget.selected) return;
    HapticFeedback.selectionClick();
    widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.geometry;
    return Semantics(
      label: '${widget.semanticsLabel} : ${widget.labels[widget.selected]}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _dragAngle = _angleAt(d.localPosition),
        onPanUpdate: (d) {
          _dragAngle = _angleAt(d.localPosition);
          _select(nearestNotch(_dragAngle!));
        },
        onPanEnd: (_) => _dragAngle = null,
        onTapUp: (d) => _select(nearestNotch(_angleAt(d.localPosition))),
        child: AnimatedBuilder(
          animation: _angle,
          builder: (_, _) => SizedBox(
            width: g.size.width,
            height: g.size.height,
            child: Stack(children: [
              // Corps du bouton : sprite tourné (brossage circulaire du
              // chapeau : la rotation de l'image est invisible, seuls les
              // reflets de la jupe vivent). L'index est peint au-dessus.
              Positioned(
                left: g.center.dx - g.knobDiameter / 2,
                top: g.center.dy - g.knobDiameter / 2,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          offset: const Offset(0, 5),
                          blurRadius: 8,
                          color: Colors.black.withValues(alpha: .6)),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: _angle.value * math.pi / 180,
                    child: Image(
                      image: VjSprites.knob,
                      width: g.knobDiameter,
                      height: g.knobDiameter,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: g.size,
                painter: _RotaryPainter(
                  geometry: g,
                  labels: widget.labels,
                  selected: widget.selected,
                  pointerAngle: _angle.value,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RotaryPainter extends CustomPainter {
  final RotaryGeometry geometry;
  final List<String> labels;
  final int selected;
  final double pointerAngle; // angle affiché (animé), en degrés depuis le haut
  _RotaryPainter({
    required this.geometry,
    required this.labels,
    required this.selected,
    required this.pointerAngle,
  });

  Offset _polar(double radius, double angleDeg) {
    final rad = angleDeg * math.pi / 180;
    return geometry.center +
        Offset(radius * math.sin(rad), -radius * math.cos(rad));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;

    // Repères, points gravés, LED du cran choisi.
    final tick = Paint()
      ..color = VjColors.print.withValues(alpha: .8)
      ..strokeWidth = g.size.width > 160 ? 1.8 : 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = rotaryAngles[i];
      canvas.drawLine(_polar(g.tickR1, a), _polar(g.tickR2, a), tick);
      final ledPos = _polar(g.ledRadius, a);
      if (i == selected) {
        canvas.drawCircle(
            ledPos,
            g.knobDiameter > 60 ? 7 : 6,
            Paint()..color = const Color(0xFFFFA640).withValues(alpha: .3));
        canvas.drawCircle(ledPos, g.knobDiameter > 60 ? 3 : 2.6,
            Paint()..color = const Color(0xFFFFD27E));
      } else {
        canvas.drawCircle(ledPos, g.knobDiameter > 60 ? 2.5 : 2.2,
            Paint()..color = const Color(0xFF33230F));
        canvas.drawCircle(
            ledPos,
            g.knobDiameter > 60 ? 2.5 : 2.2,
            Paint()
              ..color = Colors.black.withValues(alpha: .6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .6);
      }
    }

    // Libellés.
    if (g.showLabels) {
      for (var i = 0; i < 6; i++) {
        final a = rotaryAngles[i];
        final sel = i == selected;
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i].toUpperCase(),
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: g.labelFontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: sel ? VjColors.amberLabel : VjColors.printDim,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final side = a > 0 ? 1 : -1; // droite / gauche
        double x, y;
        if (a.abs() == 90) {
          x = g.center.dx + side * g.labelSideDx;
          y = g.center.dy - tp.height / 2;
        } else {
          final above = a.abs() == 30;
          x = g.center.dx + side * g.labelDiagDx;
          final baseline = g.center.dy + (above ? g.labelAboveDy : g.labelBelowDy);
          y = baseline - tp.height * .8;
        }
        tp.paint(canvas, Offset(side > 0 ? x : x - tp.width, y));
      }
    }

    // Le corps du bouton est un sprite (couche image sous ce painter) ;
    // ici ne restent que l'index et les repères.
    final knobR = g.knobDiameter / 2;

    // Index (trait crème) tourné sur l'angle affiché.
    final angle = pointerAngle;
    final ptrOuter = _polar(knobR - (g.knobDiameter > 60 ? 4 : 3), angle);
    final ptrInner =
        _polar(knobR - (g.knobDiameter > 60 ? 4 : 3) - g.knobDiameter * .39, angle);
    canvas.drawLine(
      ptrOuter,
      ptrInner,
      Paint()
        ..color = Colors.black.withValues(alpha: .45)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      ptrOuter,
      ptrInner,
      Paint()
        ..color = VjColors.pointer
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RotaryPainter old) =>
      old.selected != selected ||
      old.pointerAngle != pointerAngle ||
      old.labels != labels ||
      old.geometry != geometry;
}

/// Fenêtre ambrée sous le rotacteur compact : nom du cran choisi.
class RotaryReadout extends StatelessWidget {
  final String text;
  const RotaryReadout({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: const Color(0xFF0C0A08),
        boxShadow: [
          const BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 3,
              color: Colors.black,
              blurStyle: BlurStyle.inner),
          BoxShadow(
              offset: const Offset(0, 1),
              color: Colors.white.withValues(alpha: .07)),
        ],
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Barlow Condensed',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 11 * .18,
          color: VjColors.amberLabel,
          shadows: [
            Shadow(
                blurRadius: 6,
                color: const Color(0xFFFF9628).withValues(alpha: .7)),
          ],
        ),
      ),
    );
  }
}
