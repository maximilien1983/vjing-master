import 'package:flutter/material.dart';

import '../../autopilot/presets.dart';
import '../../cast/cast_link.dart';
import '../../session.dart';
import '../../theme/vj_tokens.dart';
import '../materials.dart';
import '../widgets/power_button.dart';
import '../widgets/rotary_selector.dart';
import 'console_screen.dart';
import 'local_screen.dart';

/// Écran de démarrage (maquette 01 simplifiée le 2026-11-24) : choisir la
/// source et les effets, puis lancer. Le bloc sources, le fader lumière, la
/// lampe « prêt » et le titre du bouton ont été retirés (demande utilisateur).
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
            'CHOOSE SOURCE AND EFFECTS, THEN LAUNCH',
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ValueListenableBuilder(
            valueListenable: session.castState,
            builder: (_, cast, _) => _selectorColumn(
              title: 'SOURCE',
              labels: sourceLabels,
              ids: sourceIds,
              notifier: session.sourceId,
              onChanged: session.setSource,
              disabled: sourceDisabledNotches(
                  castConnected: cast == CastState.connected),
            ),
          ),
          const SizedBox(width: 40),
          _selectorColumn(
            title: 'EFFECTS',
            labels: styleLabels,
            ids: styleIds,
            notifier: session.styleId,
            onChanged: session.setStyle,
          ),
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
    Set<int> disabled = const {},
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder(
          valueListenable: notifier,
          builder: (_, id, _) => RotarySelector(
            geometry: RotaryGeometry.start,
            labels: labels,
            selected: ids.indexOf(id).clamp(0, labels.length - 1),
            onChanged: (i) => onChanged(ids[i]),
            semanticsLabel: title,
            disabled: disabled,
          ),
        ),
        const SizedBox(height: 12),
        _titleRule(title, width: 136),
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

  Widget _launchPanel() {
    return Center(child: PowerButton(onPressed: _launch));
  }
}
