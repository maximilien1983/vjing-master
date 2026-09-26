import 'package:flutter/material.dart';

import '../../sources/sources_model.dart';

/// Aperçus peints des sources (SVG des maquettes transposés ; remplacés par
/// de vraies textures vidéo au jalon 4). Espace de dessin : 160 × 90.
class SourcePreview extends StatelessWidget {
  final PreviewArt art;
  final bool dimmed; // source non chargée : aperçu éteint
  const SourcePreview({super.key, required this.art, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Opacity(
        opacity: dimmed ? .38 : 1,
        child: CustomPaint(painter: _PreviewPainter(art), size: Size.infinite),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final PreviewArt art;
  _PreviewPainter(this.art);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 90);
    const full = Rect.fromLTWH(0, 0, 160, 90);
    canvas.clipRect(full);
    switch (art) {
      case PreviewArt.camera:
        _camera(canvas, full);
      case PreviewArt.neonTunnel:
        _neon(canvas, full);
      case PreviewArt.super8:
        _super8(canvas, full);
      case PreviewArt.storm:
        _storm(canvas, full);
      case PreviewArt.expo:
        _expo(canvas, full);
    }
    canvas.restore();
  }

  void _camera(Canvas c, Rect full) {
    c.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B1D14), Color(0xFF120C09)],
          ).createShader(full));
    void dot(double x, double y, double r, Color color, double a) =>
        c.drawCircle(Offset(x, y), r, Paint()..color = color.withValues(alpha: a));
    dot(30, 30, 14, const Color(0xFFFFB35A), .35);
    dot(58, 22, 8, const Color(0xFFFFD28A), .45);
    dot(112, 34, 18, const Color(0xFFFF7A6A), .25);
    dot(136, 18, 7, const Color(0xFFFFE2A8), .5);
    dot(88, 16, 5, const Color(0xFFFFC070), .5);
    final dark = Paint()..color = const Color(0xFF0A0706).withValues(alpha: .9);
    final silhouette = Path()
      ..moveTo(40, 90)
      ..cubicTo(48, 62, 62, 52, 80, 52)
      ..cubicTo(98, 52, 112, 62, 120, 90)
      ..close();
    c.drawPath(silhouette, dark);
    c.drawCircle(const Offset(80, 42), 13, dark);
  }

  void _neon(Canvas c, Rect full) {
    c.drawRect(full, Paint()..color = const Color(0xFF070512));
    void frame(double x, double y, double w, double h, double r, Color color,
        double a) {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = color.withValues(alpha: a));
    }

    frame(6, 4, 148, 82, 4, const Color(0xFFFF3FB4), .35);
    frame(22, 13, 116, 64, 4, const Color(0xFF43E6FF), .5);
    frame(38, 22, 84, 46, 3, const Color(0xFFFF3FB4), .7);
    frame(52, 30, 56, 30, 3, const Color(0xFF43E6FF), .85);
    frame(64, 37, 32, 16, 2, const Color(0xFFFF8AE0), 1);
    c.drawRect(const Rect.fromLTWH(74, 42, 12, 6),
        Paint()..color = Colors.white.withValues(alpha: .8));
  }

  void _super8(Canvas c, Rect full) {
    c.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6C27A), Color(0xFFE0764A), Color(0xFF7A3446)],
            stops: [0, .55, 1],
          ).createShader(full));
    c.drawCircle(const Offset(104, 50), 16,
        Paint()..color = const Color(0xFFFFF0C4).withValues(alpha: .9));
    c.drawRect(const Rect.fromLTWH(0, 56, 160, 34),
        Paint()..color = const Color(0xFF3D2A4A).withValues(alpha: .85));
    final sparkle = Paint()
      ..color = const Color(0xFFFFD9A0).withValues(alpha: .5)
      ..strokeWidth = 1.2;
    c.drawLine(const Offset(80, 62), const Offset(128, 62), sparkle);
    c.drawLine(const Offset(88, 68), const Offset(120, 68), sparkle);
    c.drawLine(const Offset(96, 74), const Offset(112, 74), sparkle);
    c.drawRect(
        full,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: .6),
          ], stops: const [.55, 1])
              .createShader(full));
  }

  void _storm(Canvas c, Rect full) {
    c.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A3346), Color(0xFF0E121B)],
          ).createShader(full));
    c.drawOval(Rect.fromCenter(center: const Offset(50, 24), width: 92, height: 32),
        Paint()..color = const Color(0xFF46526B));
    c.drawOval(
        Rect.fromCenter(center: const Offset(112, 20), width: 104, height: 36),
        Paint()..color = const Color(0xFF3B465C));
    final bolt = Path()
      ..moveTo(96, 30)
      ..lineTo(84, 54)
      ..lineTo(96, 54)
      ..lineTo(86, 80);
    c.drawPath(
        bolt,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFE4ECFF));
  }

  void _expo(Canvas c, Rect full) {
    // Archive 1970 : soleil orangé sur bandes rétro.
    c.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2418), Color(0xFF17100C)],
          ).createShader(full));
    c.drawCircle(const Offset(80, 38), 22,
        Paint()..color = const Color(0xFFFFA23C).withValues(alpha: .8));
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(0, 60.0 + i * 7, 160, 3.5),
          Paint()..color = const Color(0xFFB35A20).withValues(alpha: .55 - i * .1));
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.art != art;
}
