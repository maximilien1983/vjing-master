import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../autopilot/presets.dart';
import '../../cast/cast_link.dart';
import '../../session.dart';
import '../../theme/vj_tokens.dart';
import '../cast_picker.dart';
import '../materials.dart';
import '../widgets/fx_button.dart';
import '../widgets/mech_key.dart';
import '../widgets/nixie_display.dart';
import '../widgets/rotary_selector.dart';
import '../widgets/vertical_fader.dart';
import 'console_screen.dart';
import 'sources_screen.dart';

/// Mode local (maquettes 05 et 06) : vidéo plein écran sur le téléphone,
/// plaque BPM + diffusion, tiroir console escamotable (repli après 5 s
/// d'inactivité). Si une TV se connecte, on passe à la console.
class LocalScreen extends StatefulWidget {
  final Session session;
  const LocalScreen({super.key, required this.session});

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  static const _drawerHeight = 200.0;
  static const _idleDelay = Duration(seconds: 5);

  Session get session => widget.session;
  bool _open = false;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    session.castState.addListener(_onCast);
  }

  @override
  void dispose() {
    session.castState.removeListener(_onCast);
    _idle?.cancel();
    super.dispose();
  }

  void _onCast() {
    if (session.castState.value == CastState.connected && mounted) {
      // La TV prend le relais : le téléphone redevient console de pilotage.
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => ConsoleScreen(session: session)));
    }
  }

  void _setOpen(bool v) {
    setState(() => _open = v);
    _armIdle();
  }

  /// Repli automatique après 5 s sans interaction (décision produit actée).
  void _armIdle() {
    _idle?.cancel();
    if (_open) {
      _idle = Timer(_idleDelay, () {
        if (mounted) setState(() => _open = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      body: Stack(children: [
        Positioned.fill(child: session.local.buildView()),
        const Positioned.fill(
            child: GlassOverlay(scanOpacity: .12, vignette: true)),
        _plaque(context),
        // Tiroir console.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: _open ? 0 : -_drawerHeight,
          height: _drawerHeight,
          child: Listener(
            onPointerDown: (_) => _armIdle(),
            onPointerMove: (_) => _armIdle(),
            child: _drawer(),
          ),
        ),
        // Poignée « Console », solidaire du tiroir.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: _open ? _drawerHeight - 24 : 22,
          height: 48,
          child: Center(child: _handle()),
        ),
      ]),
    );
  }

  /// Plaque en haut à droite : LED tempo, BPM, sources, diffusion.
  Widget _plaque(BuildContext context) {
    return Positioned(
      right: 48,
      top: 14,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              color: const Color(0xFF121214).withValues(alpha: .62),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: .1))),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder(
                valueListenable: session.bpm,
                builder: (_, bpm, _) => TempoLed(
                    beatPhase: session.beatPhase, active: bpm > 0, size: 9),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder(
                valueListenable: session.bpm,
                builder: (_, bpm, _) => NixieDisplay(
                    bpm: bpm, tubeSize: const Size(22, 32), fontSize: 26),
              ),
              const SizedBox(width: 10),
              Text('BPM',
                  style: VjText.hint.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2)),
              const SizedBox(width: 10),
              ListenableBuilder(
                listenable: session.sourcesModel,
                builder: (context, _) => MechKey(
                  width: 48,
                  height: 48,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => SourcesScreen(session: session)),
                  ),
                  semanticsLabel:
                      'Sources vidéo : ${session.sourcesModel.loadedCount} chargées',
                  child: const Center(
                      child: Icon(Icons.video_library_outlined,
                          size: 24, color: VjColors.print)),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder(
                valueListenable: session.castState,
                builder: (_, cast, _) => CastButton(
                  active: cast == CastState.connected,
                  onTap: () => showCastPicker(context, session),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _handle() {
    return GestureDetector(
      onTap: () => _setOpen(!_open),
      onVerticalDragEnd: (d) {
        final vy = d.velocity.pixelsPerSecond.dy;
        if (vy < -80) _setOpen(true);
        if (vy > 80) _setOpen(false);
      },
      child: Semantics(
        label: _open ? 'Fermer la console' : 'Ouvrir la console',
        button: true,
        child: SizedBox(
          width: 176,
          height: 48,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 176,
              height: _open ? 30 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      offset: const Offset(0, _openShadow),
                      blurRadius: 16,
                      color: Colors.black.withValues(alpha: .5)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Row(children: [
                  const SizedBox(width: 14, child: WalnutPanel()),
                  Expanded(
                    child: AluPanel(
                      child: _open
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.keyboard_arrow_down,
                                    size: 16, color: VjColors.print),
                                const SizedBox(width: 8),
                                _handleLabel(),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.keyboard_arrow_up,
                                    size: 16, color: VjColors.print),
                                const SizedBox(height: 2),
                                _handleLabel(),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 14, child: WalnutPanel()),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _openShadow = 4.0;

  Widget _handleLabel() => Text('CONSOLE',
      style: TextStyle(
        fontFamily: 'Barlow Condensed',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 11 * .32,
        color: VjColors.print,
        height: 1,
      ));

  /// Console compacte par-dessus la vidéo.
  Widget _drawer() {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(VjDims.drawerRadius)),
        boxShadow: [
          BoxShadow(
              offset: const Offset(0, -14),
              blurRadius: 34,
              color: Colors.black.withValues(alpha: .6)),
          BoxShadow(
              offset: const Offset(0, -2),
              blurRadius: 6,
              color: Colors.black.withValues(alpha: .5)),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(VjDims.drawerRadius)),
        child: Row(children: [
          const SizedBox(width: 36, child: WalnutPanel(shadowSide: -1)),
          Expanded(
            child: AluPanel(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _compactSelectors(),
                    _divider(),
                    _compactFaders(),
                    _divider(),
                    _compactTriggers(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 36, child: WalnutPanel(shadowSide: 1)),
        ]),
      ),
    );
  }

  Widget _divider() => Container(
        width: 2,
        height: 120,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Colors.black.withValues(alpha: .5)),
            right: BorderSide(color: Colors.white.withValues(alpha: .07)),
          ),
        ),
      );

  Widget _compactSelectors() {
    Widget selector(String title, List<String> labels, List<String> ids,
        ValueNotifier<String> notifier, ValueChanged<String> onChanged) {
      return SizedBox(
        width: 136,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: VjText.sectionTitle.copyWith(height: 1)),
            const SizedBox(height: 4),
            ValueListenableBuilder(
              valueListenable: notifier,
              builder: (_, id, _) {
                final i = ids.indexOf(id).clamp(0, 5);
                return Column(children: [
                  RotarySelector(
                    geometry: RotaryGeometry.compact,
                    labels: labels,
                    selected: i,
                    onChanged: (j) {
                      onChanged(ids[j]);
                      _armIdle();
                    },
                    semanticsLabel: title,
                  ),
                  const SizedBox(height: 4),
                  RotaryReadout(text: labels[i]),
                ]);
              },
            ),
          ],
        ),
      );
    }

    return Row(children: [
      selector('UNIVERS', universeLabels, universeIds, session.universeId,
          session.setUniverse),
      const SizedBox(width: 12),
      selector('EFFECTS', styleLabels, styleIds, session.styleId,
          session.setStyle),
    ]);
  }

  Widget _compactFaders() {
    Widget fader(String title, FaderGeometry g, ValueNotifier<double> notifier,
        ValueChanged<double> onChanged) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: VjText.sectionTitle.copyWith(letterSpacing: 11 * .2)),
          const SizedBox(height: 4),
          ValueListenableBuilder(
            valueListenable: notifier,
            builder: (_, v, _) => VerticalFader(
              geometry: g,
              value: v,
              onChanged: (x) {
                onChanged(x);
                _armIdle();
              },
              semanticsLabel: title,
            ),
          ),
        ],
      );
    }

    return Row(children: [
      fader('LUMIÈRE', FaderGeometry.lightDrawer, session.light, session.setLight),
      const SizedBox(width: 16),
      fader('ÉNERGIE', FaderGeometry.energyDrawer, session.energy,
          session.setEnergy),
    ]);
  }

  /// Rangées d'effets compactes : mêmes 7 boutons 70s que la console.
  Widget _compactTriggers() {
    Widget btn(FxDef fx) => FxButton(
          label: fx.label,
          diode: fx.color,
          diameter: 34,
          litFor: () => session.fxBurst,
          onDown: () {
            _armIdle();
            if (fx.id == 'flash') {
              session.flash();
            } else {
              session.fxDown(fx.id);
            }
          },
          onUp: () {
            _armIdle();
            if (fx.id != 'flash') session.fxUp(fx.id);
          },
        );
    return SizedBox(
      width: 268,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final fx in fxDefs.take(4)) btn(fx)],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final fx in fxDefs.skip(4)) btn(fx)],
          ),
        ],
      ),
    );
  }
}
