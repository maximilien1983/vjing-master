import 'package:flutter/material.dart';

import '../../autopilot/presets.dart';
import '../../cast/cast_link.dart';
import '../../session.dart';
import '../../theme/vj_tokens.dart';
import '../materials.dart';
import '../widgets/power_button.dart';
import '../widgets/rotary_selector.dart';
import '../widgets/source_widgets.dart';
import '../widgets/vertical_fader.dart';
import 'console_screen.dart';
import 'local_screen.dart';
import 'sources_screen.dart';

/// Écran de démarrage (maquette 01) : choisir sources et ambiance, lancer.
class StartScreen extends StatefulWidget {
  final Session session;
  const StartScreen({super.key, required this.session});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.cast.startDiscovery();
  }

  void _launch() {
    session.start();
    final route = session.castState.value == CastState.connected
        ? MaterialPageRoute<void>(
            builder: (_) => ConsoleScreen(session: session))
        : MaterialPageRoute<void>(builder: (_) => LocalScreen(session: session));
    Navigator.of(context).pushReplacement(route);
  }

  @override
  Widget build(BuildContext context) {
    return VjScaffold(
      facadePadding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: Column(
        children: [
          _header(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _ambiancePanel(),
                const SizedBox(width: 20),
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: Colors.black.withValues(alpha: .5)),
                      right: BorderSide(
                          color: Colors.white.withValues(alpha: .07)),
                    ),
                  ),
                ),
                Expanded(child: _launchPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const EngravedWordmark(fontSize: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  VjColors.print.withValues(alpha: .28),
                  VjColors.print.withValues(alpha: .06),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'CHOISISSEZ SOURCES ET AMBIANCE, PUIS LANCEZ',
            style: VjText.hint.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 12 * .22),
          ),
        ],
      ),
    );
  }

  Widget _ambiancePanel() {
    return Container(
      width: 512,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
              color: Colors.white.withValues(alpha: .05),
              spreadRadius: 1,
              blurStyle: BlurStyle.inner),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _selectorColumn(
                  title: 'STYLE',
                  labels: styleLabels,
                  ids: styleIds,
                  notifier: session.styleId,
                  onChanged: session.setStyle,
                ),
                const SizedBox(width: 24),
                _selectorColumn(
                  title: 'UNIVERS',
                  labels: universeLabels,
                  ids: universeIds,
                  notifier: session.universeId,
                  onChanged: session.setUniverse,
                ),
                const SizedBox(width: 24),
                _lightColumn(),
              ],
            ),
          ),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                VjColors.print.withValues(alpha: 0),
                VjColors.print.withValues(alpha: .22),
                VjColors.print.withValues(alpha: 0),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          _sourcesBlock(),
        ],
      ),
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
            geometry: RotaryGeometry.start,
            labels: labels,
            selected: ids.indexOf(id).clamp(0, 5),
            onChanged: (i) => onChanged(ids[i]),
            semanticsLabel: title,
          ),
        ),
        const SizedBox(height: 12),
        _titleRule(title, width: 136),
      ],
    );
  }

  Widget _lightColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder(
          valueListenable: session.light,
          builder: (_, v, _) => VerticalFader(
            geometry: FaderGeometry.lightStart,
            value: v,
            onChanged: session.setLight,
            semanticsLabel: 'Lumière',
          ),
        ),
        const SizedBox(height: 10),
        const Text('LUMIÈRE', style: VjText.sectionTitle),
      ],
    );
  }

  Widget _titleRule(String title, {required double width}) {
    return SizedBox(
      width: width,
      child: Row(children: [
        Expanded(
            child: Container(color: VjColors.print.withValues(alpha: .3), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(title, style: VjText.sectionTitle.copyWith(fontSize: 12)),
        ),
        Expanded(
            child: Container(color: VjColors.print.withValues(alpha: .3), height: 1)),
      ]),
    );
  }

  Widget _sourcesBlock() {
    return ListenableBuilder(
      listenable: session.sourcesModel,
      builder: (context, _) {
        final model = session.sourcesModel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              child: Row(children: [
                const Text('SOURCES', style: VjText.sectionTitle),
                const SizedBox(width: 12),
                Text('TOUCHER POUR CHARGER OU DÉCHARGER',
                    style: VjText.hint),
                const Spacer(),
                Text(
                  '${model.loadedCount} CHARGÉE${model.loadedCount > 1 ? 'S' : ''}',
                  style: TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 11 * .18,
                    color: VjColors.amberLabel,
                    shadows: [
                      Shadow(
                          blurRadius: 6,
                          color:
                              const Color(0xFFFF9628).withValues(alpha: .6)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final s in model.sources.take(4)) ...[
                  SourceTile(source: s, onTap: () => model.toggle(s)),
                  const SizedBox(width: 10),
                ],
                AddSourceTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => SourcesScreen(session: session)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _launchPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ReadyLamp(on: true),
        const SizedBox(height: 16),
        PowerButton(onPressed: _launch),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.only(left: 22 * .42),
          child: Text(
            'LANCER',
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 22 * .42,
              color: VjColors.print,
            ),
          ),
        ),
      ],
    );
  }
}
