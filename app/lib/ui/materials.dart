import 'package:flutter/material.dart';

import '../theme/vj_tokens.dart';
import 'sprites.dart';

/// Matières de la console (DESIGN.md §4). Les surfaces viennent des textures
/// générées (assets/ui) ; les painters ne gardent que les finitions (liserés,
/// creux latéraux, ombres de jouée).

/// Façade en aluminium brossé, peinte (nette à toutes les tailles — la
/// texture image 488 px pixelisait en plein écran) : dégradé + brossage fin
/// + patine vieillie procédurale.
class AluPanel extends StatelessWidget {
  final Widget? child;
  final BorderRadius? borderRadius;
  const AluPanel({super.key, this.child, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final panel = RepaintBoundary(
      child: CustomPaint(
        painter: _AluPainter(),
        child: child,
      ),
    );
    if (borderRadius == null) return panel;
    return ClipRRect(borderRadius: borderRadius!, child: panel);
  }
}

class _AluPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VjColors.aluTop, VjColors.aluMid, VjColors.aluBottom],
          stops: [0, .5, 1],
        ).createShader(rect),
    );
    // Reflet horizontal léger.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .045),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .03),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, .3, .55, .8, 1],
        ).createShader(rect),
    );
    // Brossage : lignes horizontales 1 px à pas et opacités variés.
    final light = Paint()..color = Colors.white.withValues(alpha: .035);
    final dark = Paint()..color = Colors.black.withValues(alpha: .09);
    final faint = Paint()..color = Colors.white.withValues(alpha: .025);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), light);
    }
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), dark);
    }
    for (double y = 0; y < size.height; y += 13) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), faint);
    }
    // Patine vieillie (demande utilisateur 2026-10-07) : voiles sombres
    // irréguliers, piqûres claires et rayures d'usure — déterministes (LCG à
    // graine fixe), très discrets pour ne pas salir les contrôles posés dessus.
    var seed = 0x12345678;
    double rnd() {
      seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
      return seed / 0x7FFFFFFF;
    }

    for (var i = 0; i < 6; i++) {
      final c = Offset(rnd() * size.width, rnd() * size.height);
      final r = 50 + rnd() * 140;
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = Colors.black.withValues(alpha: .035 + rnd() * .03)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36));
    }
    final pit = Paint()..color = Colors.white.withValues(alpha: .07);
    final pitDark = Paint()..color = Colors.black.withValues(alpha: .16);
    for (var i = 0; i < 110; i++) {
      final p = Offset(rnd() * size.width, rnd() * size.height);
      final w = 1 + rnd() * 1.6;
      canvas.drawRect(
          Rect.fromLTWH(p.dx, p.dy, w, 1), rnd() < .6 ? pitDark : pit);
    }
    // Quelques rayures horizontales plus franches (sens du brossage).
    for (var i = 0; i < 9; i++) {
      final y = rnd() * size.height;
      final x = rnd() * size.width * .75;
      final w = 24 + rnd() * 110;
      canvas.drawRect(Rect.fromLTWH(x, y, w, 1),
          Paint()..color = Colors.white.withValues(alpha: .04 + rnd() * .035));
    }

    // Liseré clair en haut (inset 0 1px 0 rgba(255,255,255,.14)).
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1),
        Paint()..color = Colors.white.withValues(alpha: .14));
    // Creux latéraux (inset ±4px 0 6px rgba(0,0,0,.55)).
    final edge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: .55),
          Colors.black.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, 8, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 8, size.height), edge);
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    canvas.drawRect(Rect.fromLTWH(0, 0, 8, size.height), edge);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AluPainter oldDelegate) => false;
}

/// Joue en noyer : texture + ombre interne côté façade.
class WalnutPanel extends StatelessWidget {
  /// Ombre interne côté façade : -1 = façade à gauche, 1 = à droite, 0 = aucune.
  final int shadowSide;
  const WalnutPanel({super.key, this.shadowSide = 0});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: VjSprites.texWalnut,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        child: CustomPaint(
          painter: _WalnutPainter(shadowSide),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WalnutPainter extends CustomPainter {
  final int shadowSide;
  _WalnutPainter(this.shadowSide);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    // La matière vient de la texture (VjSprites.texWalnut).
    // Ombre interne côté façade.
    if (shadowSide != 0) {
      final w = 12.0;
      final left = shadowSide < 0;
      final shadowRect = Rect.fromLTWH(left ? 0 : size.width - w, 0, w, size.height);
      canvas.drawRect(
        shadowRect,
        Paint()
          ..shader = LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              Colors.black.withValues(alpha: .45),
              Colors.black.withValues(alpha: 0),
            ],
          ).createShader(shadowRect),
      );
      // Liseré chaud côté façade.
      canvas.drawRect(
        Rect.fromLTWH(left ? size.width - 1 : 0, 0, 1, size.height),
        Paint()..color = const Color(0xFFFFDCB4).withValues(alpha: .10),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WalnutPainter oldDelegate) =>
      oldDelegate.shadowSide != shadowSide;
}

/// Zone enfoncée : fond sombre + ombre interne en haut + liseré clair en bas.
class RecessPanel extends StatelessWidget {
  final Widget? child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  const RecessPanel({
    super.key,
    this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(VjDims.recessRadius)),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RecessPainter(borderRadius),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

class _RecessPainter extends CustomPainter {
  final BorderRadius borderRadius;
  _RecessPainter(this.borderRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    // Liseré clair sous le creux (0 1px 0 rgba(255,255,255,.07)).
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1)),
      Paint()..color = Colors.white.withValues(alpha: .07),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VjColors.recessTop, VjColors.recessBottom],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    // Ombre interne : rectangle flouté au-dessus du bord haut.
    canvas.drawRect(
      Rect.fromLTWH(-4, -6, size.width + 8, 8),
      Paint()
        ..color = Colors.black.withValues(alpha: .85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Liseré clair interne en bas (inset 0 -1px 0 rgba(255,255,255,.05)).
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = Colors.white.withValues(alpha: .05),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RecessPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}

/// Écran incrusté (vignette source, moniteur) : lunette en dégradé sombre.
class BezelPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool lit; // liseré + halo ambrés (source à l'image)
  const BezelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(4),
    this.radius = VjDims.thumbRadius,
    this.lit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C2D30), Color(0xFF0F0F10)],
        ),
        boxShadow: [
          const BoxShadow(offset: Offset(0, 2), blurRadius: 3, color: Color(0xB3000000)),
          if (lit) ...[
            BoxShadow(
                color: const Color(0xFFFFB450).withValues(alpha: .45),
                spreadRadius: 1),
            BoxShadow(
                color: const Color(0xFFFFA032).withValues(alpha: .25),
                blurRadius: 12),
          ],
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: .12), width: 1)),
      ),
      child: child,
    );
  }
}

/// Vitre au-dessus d'un aperçu vidéo : lignes de balayage + reflet.
class GlassOverlay extends StatelessWidget {
  final double scanOpacity;
  final bool vignette;
  const GlassOverlay({super.key, this.scanOpacity = .2, this.vignette = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GlassPainter(scanOpacity, vignette),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final double scanOpacity;
  final bool vignette;
  _GlassPainter(this.scanOpacity, this.vignette);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final scan = Paint()..color = Colors.black.withValues(alpha: scanOpacity);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
    if (vignette) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: .5),
          ], stops: const [.55, 1])
              .createShader(rect),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .1),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, .45],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) =>
      old.scanOpacity != scanOpacity || old.vignette != vignette;
}

/// Gabarit d'écran : joues noyer + façade alu (DESIGN.md §5, VjScaffold).
class VjScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsets facadePadding;
  const VjScaffold({super.key, required this.child, required this.facadePadding});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final cheek = VjDims.cheekWidth;
    return Scaffold(
      backgroundColor: VjColors.ground,
      body: Row(
        children: [
          SizedBox(
              width: cheek < safe.left ? safe.left : cheek,
              child: const WalnutPanel(shadowSide: -1)),
          Expanded(
            child: AluPanel(
              child: Padding(padding: facadePadding, child: child),
            ),
          ),
          SizedBox(
              width: cheek < safe.right ? safe.right : cheek,
              child: const WalnutPanel(shadowSide: 1)),
        ],
      ),
    );
  }
}

/// Signature « VJing Master » gravée (Gajraj One, ombre au-dessus, reflet dessous).
class EngravedWordmark extends StatelessWidget {
  final double fontSize;
  const EngravedWordmark({super.key, this.fontSize = 25});

  @override
  Widget build(BuildContext context) {
    return Text(
      'VJing Master',
      maxLines: 1,
      overflow: TextOverflow.visible,
      softWrap: false,
      style: VjText.wordmark.copyWith(
        fontSize: fontSize,
        color: VjColors.print.withValues(alpha: .8),
        shadows: [
          const Shadow(offset: Offset(0, -1), color: Color(0xBF000000)),
          Shadow(offset: const Offset(0, 1), color: Colors.white.withValues(alpha: .12)),
        ],
      ),
    );
  }
}
