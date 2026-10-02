import 'package:flutter/material.dart';

import '../../autopilot/presets.dart';
import '../../cast/cast_link.dart';
import '../../session.dart';
import '../../sources/sources_model.dart';
import '../../theme/vj_tokens.dart';
import '../cast_picker.dart';
import '../materials.dart';
import '../widgets/fx_button.dart';
import '../widgets/mech_key.dart';
import '../widgets/nixie_display.dart';
import '../widgets/on_air_lamp.dart';
import '../widgets/rotary_selector.dart';
import '../widgets/source_widgets.dart';
import '../widgets/vertical_fader.dart';
import 'sources_screen.dart';

/// Console principale (maquettes 02 et 03 : mêmes widgets, états différents
/// selon la diffusion). Tous les contrôles pilotent la Session.
class ConsoleScreen extends StatelessWidget {
  final Session session;
  const ConsoleScreen({super.key, required this.session});

  void _openSources(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SourcesScreen(session: session)));
  }

  @override
  Widget build(BuildContext context) {
    return VjScaffold(
      facadePadding: const EdgeInsets.fromLTRB(8, 10, 8, 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _topRecess(context),
                const SizedBox(height: 8),
                Expanded(child: _controlsRow(context)),
                _bottomRule(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _energyColumn(),
        ],
      ),
    );
  }

  /// Bandeau enfoncé du haut : vignettes sources, moniteur, On Air + BPM.
  Widget _topRecess(BuildContext context) {
    return RecessPanel(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: _sourcesStrip(context))),
            const SizedBox(width: 12),
            // Aperçu de la sortie : le moteur local rend le même flux que la TV.
            VideoMonitor(child: session.local.buildView()),
            const SizedBox(width: 12),
            _statusCluster(context),
          ],
        ),
      ),
    );
  }

  Widget _sourcesStrip(BuildContext context) {
    return ListenableBuilder(
      listenable: session.sourcesModel,
      builder: (context, _) {
        final model = session.sourcesModel;
        final shown = model.sources.take(3).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 14,
              child: Row(children: [
                const Text('SOURCES', style: VjText.sectionTitle),
                const SizedBox(width: 10),
                Text('TOUCHER POUR CHANGER',
                    style: VjText.hint.copyWith(fontSize: 10)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        VjColors.print.withValues(alpha: .3),
                        VjColors.print.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              for (final s in shown) ...[
                SourceThumbnail(
                  source: s,
                  // Jalon 3 : allumée si chargée (l'autoplay vidéo arrive au 4).
                  lit: s.state == SourceState.loaded,
                  onTap: () => _openSources(context),
                ),
                const SizedBox(width: 12),
              ],
            ]),
          ],
        );
      },
    );
  }

  /// On Air, bouton diffusion, LED tempo, BPM.
  Widget _statusCluster(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 120,
      child: Column(children: [
        SizedBox(
          height: 48,
          child: Row(children: [
            ValueListenableBuilder(
              valueListenable: session.castState,
              builder: (_, cast, _) =>
                  OnAirLamp(on: cast == CastState.connected),
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
        const SizedBox(height: 6),
        SizedBox(
          height: 14,
          child: Row(children: [
            ValueListenableBuilder(
              valueListenable: session.bpm,
              builder: (_, bpm, _) => TempoLed(
                beatPhase: session.beatPhase,
                active: bpm > 0,
                size: 10,
              ),
            ),
            const SizedBox(width: 7),
            const Expanded(child: Text('TEMPO', style: VjText.sectionTitle)),
            Text('BPM',
                style: VjText.hint.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2)),
          ]),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder(
          valueListenable: session.bpm,
          builder: (_, bpm, _) => NixieDisplay(bpm: bpm),
        ),
      ]),
    );
  }

  /// Rangée centrale : rotacteurs, lumière, déclencheurs.
  Widget _controlsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _selectorColumn(
          title: 'UNIVERS',
          labels: universeLabels,
          ids: universeIds,
          notifier: session.universeId,
          onChanged: session.setUniverse,
        ),
        _selectorColumn(
          title: 'EFFECTS',
          labels: styleLabels,
          ids: styleIds,
          notifier: session.styleId,
          onChanged: session.setStyle,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder(
              valueListenable: session.light,
              builder: (_, v, _) => VerticalFader(
                geometry: FaderGeometry.lightConsole,
                value: v,
                onChanged: session.setLight,
                semanticsLabel: 'Lumière',
              ),
            ),
            const SizedBox(height: 6),
            Text('LUMIÈRE',
                style: VjText.sectionTitle.copyWith(letterSpacing: 11 * .22)),
          ],
        ),
        _triggersBlock(),
      ],
    );
  }

  Widget _selectorColumn({
    required String title,
    required List<String> labels,
    required List<String> ids,
    required ValueNotifier<String> notifier,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder(
          valueListenable: notifier,
          builder: (_, id, _) => RotarySelector(
            geometry: RotaryGeometry.console,
            labels: labels,
            selected: ids.indexOf(id).clamp(0, 5),
            onChanged: (i) => onChanged(ids[i]),
            semanticsLabel: title,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 120,
          child: Row(children: [
            Expanded(
                child:
                    Container(color: VjColors.print.withValues(alpha: .3), height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(title, style: VjText.sectionTitle),
            ),
            Expanded(
                child:
                    Container(color: VjColors.print.withValues(alpha: .3), height: 1)),
          ]),
        ),
      ],
    );
  }

  /// Rangées d'effets : 7 boutons-poussoirs 70s (diode, couronne métal).
  /// Tap = burst d'une mesure, maintien = effet prolongé (flash : armé sur le
  /// prochain temps par le moteur).
  Widget _triggersBlock() {
    Widget btn(FxDef fx) => FxButton(
          label: fx.label,
          diode: fx.color,
          diameter: 42,
          litFor: () => session.fxBurst,
          onDown: () =>
              fx.id == 'flash' ? session.flash() : session.fxDown(fx.id),
          onUp: () {
            if (fx.id != 'flash') session.fxUp(fx.id);
          },
        );
    return SizedBox(
      width: 282,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final fx in fxDefs.take(4)) btn(fx)],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final fx in fxDefs.skip(4)) btn(fx)],
          ),
        ],
      ),
    );
  }

  Widget _bottomRule() {
    return SizedBox(
      height: 20,
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, right: 4),
          child: EngravedWordmark(fontSize: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                VjColors.print.withValues(alpha: .28),
                VjColors.print.withValues(alpha: 0),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _energyColumn() {
    return Container(
      width: 68,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.black.withValues(alpha: .45)),
        ),
      ),
      child: Column(children: [
        Text('ÉNERGIE',
            style: VjText.sectionTitle.copyWith(letterSpacing: 11 * .2)),
        const SizedBox(height: 8),
        ValueListenableBuilder(
          valueListenable: session.energy,
          builder: (_, v, _) => VerticalFader(
            geometry: FaderGeometry.energyConsole,
            value: v,
            onChanged: session.setEnergy,
            semanticsLabel: 'Énergie',
          ),
        ),
      ]),
    );
  }
}
