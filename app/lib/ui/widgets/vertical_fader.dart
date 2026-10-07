import 'package:flutter/material.dart';

import '../../theme/vj_tokens.dart';
import '../sprites.dart';

/// Géométrie d'un fader vertical (valeurs des maquettes).
class FaderGeometry {
  final Size size;
  final double tickTop, tickBottom; // course utile (valeur 1 en haut, 0 en bas)
  final double slotTop, slotHeight, slotX; // rainure (x = bord gauche)
  final Size cap;
  final int ticks; // graduations principales (espacées régulièrement)
  final int longEvery; // graduation longue toutes les N
  final int minorsBetween; // petites graduations entre deux principales
  final bool numbers; // 100 → 0 à gauche des graduations
  final String? topLabel, bottomLabel;

  const FaderGeometry({
    required this.size,
    required this.tickTop,
    required this.tickBottom,
    required this.slotTop,
    required this.slotHeight,
    required this.slotX,
    required this.cap,
    required this.ticks,
    this.longEvery = 1,
    this.minorsBetween = 0,
    this.numbers = false,
    this.topLabel,
    this.bottomLabel,
  });

  /// Lumière, écran de démarrage : 64 × 124, curseur 52 × 24.
  static const lightStart = FaderGeometry(
    size: Size(64, 124),
    tickTop: 20,
    tickBottom: 100,
    slotTop: 16,
    slotHeight: 88,
    slotX: 29,
    cap: Size(52, 24),
    ticks: 11,
    longEvery: 5,
    topLabel: 'LUMINEUX',
    bottomLabel: 'DARK',
  );

  /// Lumière, console : 56 × 164, curseur 48 × 26.
  static const lightConsole = FaderGeometry(
    size: Size(56, 164),
    tickTop: 20,
    tickBottom: 142,
    slotTop: 16,
    slotHeight: 130,
    slotX: 25,
    cap: Size(48, 26),
    ticks: 11,
    longEvery: 5,
    topLabel: 'LUMINEUX',
    bottomLabel: 'DARK',
  );

  /// Énergie, console : 68 × 336, curseur 52 × 30, gradué de 0 à 100.
  static const energyConsole = FaderGeometry(
    size: Size(68, 336),
    tickTop: 16,
    tickBottom: 320,
    slotTop: 10,
    slotHeight: 316,
    slotX: 39,
    cap: Size(52, 30),
    ticks: 11,
    minorsBetween: 1,
    numbers: true,
  );

  /// Lumière, tiroir du mode local : 52 × 128, curseur 44 × 24.
  static const lightDrawer = FaderGeometry(
    size: Size(52, 128),
    tickTop: 16,
    tickBottom: 110,
    slotTop: 12,
    slotHeight: 102,
    slotX: 23,
    cap: Size(44, 24),
    ticks: 5,
    longEvery: 2,
    topLabel: 'LUMINEUX',
    bottomLabel: 'DARK',
  );

  /// Énergie, tiroir : 60 × 128, curseur 46 × 24, gradué 100 / 50 / 0.
  static const energyDrawer = FaderGeometry(
    size: Size(60, 128),
    tickTop: 12,
    tickBottom: 116,
    slotTop: 6,
    slotHeight: 116,
    slotX: 34,
    cap: Size(46, 24),
    ticks: 3,
    minorsBetween: 4,
    numbers: true,
  );

  /// Opacité caméra, console : compact sous le bouton caméra.
  static const cameraConsole = FaderGeometry(
    size: Size(52, 104),
    tickTop: 12,
    tickBottom: 92,
    slotTop: 8,
    slotHeight: 88,
    slotX: 23,
    cap: Size(44, 22),
    ticks: 5,
    longEvery: 2,
  );

  /// Opacité caméra, tiroir du mode local : étroit pour tenir sur la rangée.
  static const cameraDrawer = FaderGeometry(
    size: Size(44, 128),
    tickTop: 16,
    tickBottom: 110,
    slotTop: 12,
    slotHeight: 102,
    slotX: 19,
    cap: Size(38, 24),
    ticks: 5,
    longEvery: 2,
  );

  double centerYFor(double value) =>
      tickTop + (1 - value.clamp(0.0, 1.0)) * (tickBottom - tickTop);

  double valueFor(double y) =>
      (1 - (y - tickTop) / (tickBottom - tickTop)).clamp(0.0, 1.0);
}

/// Fader vertical : toute la colonne est tactile, pas seulement le curseur.
class VerticalFader extends StatelessWidget {
  final FaderGeometry geometry;
  final double value; // 0-1
  final ValueChanged<double> onChanged;
  final String semanticsLabel;
  const VerticalFader({
    super.key,
    required this.geometry,
    required this.value,
    required this.onChanged,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    final capTop = g.centerYFor(value) - g.cap.height / 2;
    return Semantics(
      label: semanticsLabel,
      value: '${(value * 100).round()}',
      slider: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onChanged(g.valueFor(d.localPosition.dy)),
        onTapDown: (d) => onChanged(g.valueFor(d.localPosition.dy)),
        child: SizedBox(
          width: g.size.width,
          height: g.size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _FaderScalePainter(g))),
              // Plaque-rainure : sprite vissé, étiré sur la course.
              Positioned(
                left: g.slotX + 3 - 13,
                top: g.slotTop - 10,
                child: Image(
                  image: VjSprites.faderRail,
                  width: 26,
                  height: g.slotHeight + 20,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              // Curseur.
              Positioned(
                left: g.slotX + 3 - g.cap.width / 2,
                top: capTop,
                child: _FaderCap(size: g.cap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaderCap extends StatelessWidget {
  final Size size;
  const _FaderCap({required this.size});

  @override
  Widget build(BuildContext context) {
    // Sprite du capuchon strié (ligne crème incluse dans l'image).
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
              offset: const Offset(0, 6),
              blurRadius: 10,
              color: Colors.black.withValues(alpha: .7)),
          BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 3,
              color: Colors.black.withValues(alpha: .8)),
        ],
      ),
      child: Image(
        image: VjSprites.faderCap,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _FaderScalePainter extends CustomPainter {
  final FaderGeometry g;
  _FaderScalePainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = g.slotX + 3;
    final strong = Paint()
      ..color = VjColors.print.withValues(alpha: .7)
      ..strokeWidth = 1;
    final weak = Paint()
      ..color = VjColors.print.withValues(alpha: .45)
      ..strokeWidth = 1;
    final step = (g.tickBottom - g.tickTop) / (g.ticks - 1);
    for (var i = 0; i < g.ticks; i++) {
      final y = g.tickTop + i * step;
      final isLong = g.longEvery <= 1 || i % g.longEvery == 0;
      final len = isLong ? 12.0 : 7.0;
      canvas.drawLine(Offset(cx - 5 - len, y), Offset(cx - 5, y), strong);
      canvas.drawLine(Offset(cx + 5, y), Offset(cx + 5 + len, y), strong);
      if (g.numbers) {
        final v = 100 - (100 * i / (g.ticks - 1)).round();
        final tp = TextPainter(
          text: TextSpan(
            text: '$v',
            style: const TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: VjColors.printDim,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - 5 - 14 - tp.width, y - tp.height / 2));
      }
      if (g.minorsBetween > 0 && i < g.ticks - 1) {
        for (var m = 1; m <= g.minorsBetween; m++) {
          final ym = y + step * m / (g.minorsBetween + 1);
          canvas.drawLine(Offset(cx - 5 - 4, ym), Offset(cx - 5, ym), weak);
          canvas.drawLine(Offset(cx + 5, ym), Offset(cx + 5 + 4, ym), weak);
        }
      }
    }
    void label(String? text, double y, bool above) {
      if (text == null) return;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: 'Barlow Condensed',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: .8,
            color: VjColors.printDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(cx - tp.width / 2, above ? y - tp.height - 3 : y + 4));
    }

    label(g.topLabel, g.tickTop, true);
    label(g.bottomLabel, g.tickBottom, false);
  }

  @override
  bool shouldRepaint(covariant _FaderScalePainter old) => old.g != g;
}
