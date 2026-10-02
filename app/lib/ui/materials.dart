import 'package:flutter/material.dart';

import '../theme/vj_tokens.dart';

/// Matières de la console (DESIGN.md §4). Chaque painter reproduit les
/// dégradés CSS des maquettes : les valeurs viennent de screens/*.html.

/// Façade en aluminium brossé : dégradé vertical + fines lignes horizontales
/// + léger reflet horizontal.
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

/// Joue en noyer : dégradé horizontal 5 arrêts + grain vertical.
class WalnutPanel extends StatelessWidget {
  /// Ombre interne côté façade : -1 = façade à gauche, 1 = à droite, 0 = aucune.
  final int shadowSide;
  const WalnutPanel({super.key, this.shadowSide = 0});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WalnutPainter(shadowSide),
        size: Size.infinite,
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
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: VjColors.walnut,
          stops: const [0, .25, .5, .75, 1],
        ).createShader(rect),
    );
    // Reflets chauds (radial-gradient des maquettes, approchés).
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * .4, size.height * .3),
          width: size.width * 1.2,
          height: size.height * .36),
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFF824E28).withValues(alpha: .35),
          const Color(0x00824E28),
        ]).createShader(Rect.fromCenter(
            center: Offset(size.width * .4, size.height * .3),
            width: size.width * 1.2,
            height: size.height * .36))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Grain : traits verticaux fins, quasi verticaux (91° / 88.5°).
    final grain1 = Paint()..color = Colors.black.withValues(alpha: .22);
    final grain2 = Paint()..color = const Color(0xFFFFC896).withValues(alpha: .05);
    final grain3 = Paint()..color = Colors.black.withValues(alpha: .18);
    canvas.save();
    canvas.clipRect(rect);
    for (double x = -6; x < size.width + 6; x += 7) {
      canvas.drawLine(Offset(x, -4), Offset(x - size.height * .017, size.height + 4),
          grain1..strokeWidth = 1);
      canvas.drawLine(Offset(x + 3, -4),
          Offset(x + 3 - size.height * .017, size.height + 4), grain2..strokeWidth = 1);
    }
    for (double x = -8; x < size.width + 8; x += 11) {
      canvas.drawLine(Offset(x, -4), Offset(x + size.height * .026, size.height + 4),
          grain3..strokeWidth = 2);
    }
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
