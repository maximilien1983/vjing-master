import 'package:flutter/material.dart';

import '../../sources/sources_model.dart';
import '../../theme/vj_tokens.dart';
import '../materials.dart';
import 'leds.dart';
import 'mech_key.dart';

import 'source_previews.dart';

/// Vignette source de la console : cadre 96 × 58, écran 88 × 50, étiquette
/// LED + nom + icône d'échange. Toucher = changer la source de cette vignette.
class SourceThumbnail extends StatelessWidget {
  final VideoSource source;
  final bool lit; // l'autoplay l'utilise en ce moment
  final VoidCallback onTap;
  const SourceThumbnail({
    super.key,
    required this.source,
    required this.lit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Changer la source (actuelle : ${source.name})',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BezelPanel(
                lit: lit,
                child: SizedBox(
                  width: 88,
                  height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(fit: StackFit.expand, children: [
                      SourcePreview(art: source.art),
                      const GlassOverlay(),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 12,
                child: Row(children: [
                  AmberLed(on: lit, size: 7),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      source.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: 'Barlow Condensed',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 9.5 * .06,
                        color: lit ? VjColors.print : VjColors.printDim,
                      ),
                    ),
                  ),
                  const _SwapIcon(),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapIcon extends StatelessWidget {
  const _SwapIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(11, 11), painter: _SwapIconPainter());
  }
}

class _SwapIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()
      ..color = VjColors.printDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()
          ..moveTo(16 * s, 3 * s)
          ..lineTo(20 * s, 7 * s)
          ..lineTo(16 * s, 11 * s),
        p);
    canvas.drawLine(Offset(20 * s, 7 * s), Offset(6 * s, 7 * s), p);
    canvas.drawPath(
        Path()
          ..moveTo(8 * s, 21 * s)
          ..lineTo(4 * s, 17 * s)
          ..lineTo(8 * s, 13 * s),
        p);
    canvas.drawLine(Offset(4 * s, 17 * s), Offset(18 * s, 17 * s), p);
  }

  @override
  bool shouldRepaint(covariant _SwapIconPainter old) => false;
}

/// Tuile source de l'écran de démarrage : 88 × 72, toucher pour charger
/// ou décharger.
class SourceTile extends StatelessWidget {
  final VideoSource source;
  final VoidCallback onTap;
  const SourceTile({super.key, required this.source, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loaded = source.state == SourceState.loaded;
    return Semantics(
      label: source.name,
      toggled: loaded,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 88,
          child: Column(children: [
            BezelPanel(
              lit: loaded,
              child: SizedBox(
                width: 80,
                height: 46,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(fit: StackFit.expand, children: [
                    SourcePreview(art: source.art, dimmed: !loaded),
                    const GlassOverlay(),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 12,
              child: Row(children: [
                AmberLed(on: loaded, size: 7),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    source.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Barlow Condensed',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: loaded ? VjColors.print : VjColors.printDim,
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tuile « Ajouter » en fin de rangée (démarrage).
class AddSourceTile extends StatelessWidget {
  final VoidCallback? onTap;
  const AddSourceTile({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ajouter une source',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(children: [
            Container(
              width: 64,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [VjColors.recessTop, VjColors.recessBottom],
                ),
                boxShadow: [
                  const BoxShadow(
                      offset: Offset(0, 2),
                      blurRadius: 5,
                      color: Color(0xD9000000),
                      blurStyle: BlurStyle.inner),
                  BoxShadow(
                      offset: const Offset(0, 1),
                      color: Colors.white.withValues(alpha: .07)),
                ],
              ),
              child: const Icon(Icons.add, size: 20, color: VjColors.print),
            ),
            const SizedBox(height: 6),
            const SizedBox(
              height: 12,
              child: Text('AJOUTER',
                  style: TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: VjColors.print,
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Moniteur de sortie : 200 × 120, écran 186 × 106, reflet + vignettage.
class VideoMonitor extends StatelessWidget {
  final Widget child; // texture vidéo réduite (vue moteur)
  const VideoMonitor({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aperçu de la vidéo diffusée',
      child: BezelPanel(
        padding: const EdgeInsets.all(7),
        radius: 8,
        child: SizedBox(
          width: 186,
          height: 106,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: const Color(0xFF07060F), child: child),
              const GlassOverlay(scanOpacity: .22, vignette: true),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ligne de l'écran Sources : icône de type, nom, méta, étiquette Boucle,
/// état (LED + libellé, progression) et touche d'action.
class SourceRow extends StatelessWidget {
  final VideoSource source;
  final VoidCallback onAction;
  const SourceRow({super.key, required this.source, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final (action, stateLabel, stateColor) = switch (source.state) {
      SourceState.loaded => ('Décharger', 'CHARGÉE', VjColors.print),
      SourceState.loading => ('Annuler', 'CHARGEMENT', VjColors.amberLabel),
      SourceState.unloaded => ('Charger', 'NON CHARGÉE', VjColors.printDim),
    };
    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C2D31), Color(0xFF232427)],
        ),
        boxShadow: [
          BoxShadow(
              offset: const Offset(0, 1),
              color: Colors.white.withValues(alpha: .07),
              blurStyle: BlurStyle.inner),
          BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withValues(alpha: .6)),
        ],
      ),
      child: Row(children: [
        _TypeBadge(kind: source.kind),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 16 * .02,
                    color: VjColors.print,
                  )),
              const SizedBox(height: 2),
              Text(source.meta.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 10.5 * .18,
                    color: VjColors.printDim,
                  )),
            ],
          ),
        ),
        if (source.loop) ...[const _LoopTag(), const SizedBox(width: 14)],
        SizedBox(
          width: 112,
          child: source.state == SourceState.loading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _BlinkingLed(),
                      const SizedBox(width: 8),
                      Text(stateLabel, style: _stateStyle(stateColor)),
                    ]),
                    const SizedBox(height: 5),
                    _ProgressBar(value: source.progress),
                  ],
                )
              : Row(children: [
                  AmberLed(on: source.state == SourceState.loaded, size: 9),
                  const SizedBox(width: 8),
                  Text(stateLabel, style: _stateStyle(stateColor)),
                ]),
        ),
        MechKey(
          width: 128,
          onTap: onAction,
          semanticsLabel: '$action ${source.name}',
          child: Center(
              child: Text(action.toUpperCase(), style: VjText.keyLabel)),
        ),
      ]),
    );
  }

  static TextStyle _stateStyle(Color color) => TextStyle(
        fontFamily: 'Barlow Condensed',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 11 * .2,
        color: color,
      );
}

class _TypeBadge extends StatelessWidget {
  final SourceKind kind;
  const _TypeBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: const Color(0xFF131315),
        boxShadow: [
          const BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 3,
              color: Colors.black,
              blurStyle: BlurStyle.inner),
          BoxShadow(
              offset: const Offset(0, 1),
              color: Colors.white.withValues(alpha: .06)),
        ],
      ),
      child: Icon(
        switch (kind) {
          SourceKind.camera => Icons.photo_camera_outlined,
          SourceKind.file => Icons.movie_outlined,
          SourceKind.remote => Icons.cloud_download_outlined,
        },
        size: 22,
        color: VjColors.print,
      ),
    );
  }
}

class _LoopTag extends StatelessWidget {
  const _LoopTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: VjColors.print.withValues(alpha: .3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.repeat, size: 12, color: VjColors.printDim),
        const SizedBox(width: 5),
        Text('BOUCLE',
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 10 * .18,
              color: VjColors.printDim,
            )),
      ]),
    );
  }
}

class _BlinkingLed extends StatefulWidget {
  @override
  State<_BlinkingLed> createState() => _BlinkingLedState();
}

class _BlinkingLedState extends State<_BlinkingLed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) =>
          AmberLed(on: true, size: 9, intensity: .25 + .75 * (1 - _c.value)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: const Color(0xFF0B0A09),
        boxShadow: const [
          BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 1,
              color: Colors.black,
              blurStyle: BlurStyle.inner),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 104 * value.clamp(0.0, 1.0),
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
                colors: [Color(0xFFD9741A), Color(0xFFFFC15A)]),
            boxShadow: [
              BoxShadow(
                  blurRadius: 6,
                  color: const Color(0xFFFFA032).withValues(alpha: .6)),
            ],
          ),
        ),
      ),
    );
  }
}
