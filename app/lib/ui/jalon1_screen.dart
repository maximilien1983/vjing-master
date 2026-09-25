import 'package:flutter/material.dart';

import '../audio/audio_analyzer.dart';
import '../cast/cast_link.dart';
import '../session.dart';

/// Écran de validation des jalons 1-2 : rendu plein écran + bandeau de
/// contrôle technique (BPM, niveaux, structure, énergie, lumière,
/// déclencheurs, Cast). La vraie console (design table de mixage) arrive
/// au jalon 3.
class Jalon1Screen extends StatefulWidget {
  const Jalon1Screen({super.key});

  @override
  State<Jalon1Screen> createState() => _Jalon1ScreenState();
}

class _Jalon1ScreenState extends State<Jalon1Screen> {
  final session = Session();
  bool _overlayVisible = true;

  @override
  void initState() {
    super.initState();
    session.start();
    session.cast.startDiscovery();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: session.local.buildView()),
          if (_overlayVisible)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: _ControlBar(session: session),
              ),
            ),
          // Coin bas-droit : masquer/afficher le bandeau.
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton(
              icon: Icon(
                _overlayVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.white38,
              ),
              onPressed: () =>
                  setState(() => _overlayVisible = !_overlayVisible),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final Session session;
  const _ControlBar({required this.session});

  static const _structureLabels = {
    StructureState.calm: 'CALME',
    StructureState.steady: 'STABLE',
    StructureState.rise: 'MONTÉE',
    StructureState.drop: 'DROP',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder(
                valueListenable: session.micOk,
                builder: (_, ok, _) => Icon(
                  ok == false ? Icons.mic_off : Icons.mic,
                  size: 18,
                  color: switch (ok) {
                    true => Colors.greenAccent,
                    false => Colors.redAccent,
                    null => Colors.white38,
                  },
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder(
                valueListenable: session.bpm,
                builder: (_, bpm, _) => Text(
                  bpm > 0 ? '${bpm.toStringAsFixed(1)} BPM' : '— BPM',
                  style: const TextStyle(
                    color: Color(0xFFFFB566),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder(
                valueListenable: session.structure,
                builder: (_, s, _) => Text(
                  _structureLabels[s]!,
                  style: TextStyle(
                    color: s == StructureState.drop
                        ? Colors.redAccent
                        : (s == StructureState.rise
                            ? const Color(0xFFFFB566)
                            : Colors.white54),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder(
                valueListenable: session.levels,
                builder: (_, l, _) => _LevelBars(levels: l),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder(
                valueListenable: session.latency,
                builder: (_, v, _) => _InfoText('lat $v'),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder(
                valueListenable: session.stats,
                builder: (_, v, _) => _InfoText(v),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Debug moteur',
                icon: const Icon(Icons.bug_report,
                    color: Colors.white70, size: 20),
                onPressed: () => session.setDebug(!session.debug),
              ),
              ValueListenableBuilder(
                valueListenable: session.castState,
                builder: (_, s, _) => IconButton(
                  tooltip: 'Diffuser',
                  icon: Icon(
                    s == CastState.connected
                        ? Icons.cast_connected
                        : Icons.cast,
                    color: s == CastState.connected
                        ? const Color(0xFFFFB566)
                        : Colors.white70,
                    size: 20,
                  ),
                  onPressed: () => _showCastPicker(context),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Fader(
                label: 'ÉNERGIE',
                listenable: session.energy,
                onChanged: session.setEnergy,
              ),
              _Fader(
                label: 'LUMIÈRE',
                listenable: session.light,
                onChanged: session.setLight,
              ),
              _SyncFader(session: session),
              ValueListenableBuilder(
                valueListenable: session.beatBar,
                builder: (_, on, _) => FilterChip(
                  label: const Text('CAL'),
                  selected: on,
                  showCheckmark: false,
                  tooltip: 'Barre de calibration : flash sur chaque temps',
                  labelStyle: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: on ? const Color(0xFF4A2305) : Colors.white70,
                  ),
                  selectedColor: const Color(0xFFFFB547),
                  backgroundColor: Colors.white10,
                  onSelected: session.setBeatBar,
                ),
              ),
              _TriggerButton('FLASH', onPressed: session.flash),
              _TriggerButton('DROP', onPressed: session.drop),
              _TriggerButton('SCÈNE', onPressed: session.scene),
              _TriggerButton('SUIVANT', onPressed: session.next),
              ValueListenableBuilder(
                valueListenable: session.hold,
                builder: (_, holding, _) => FilterChip(
                  label: const Text('GARDER'),
                  selected: holding,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: holding ? const Color(0xFF4A2305) : Colors.white70,
                  ),
                  selectedColor: const Color(0xFFFFB547),
                  backgroundColor: Colors.white10,
                  onSelected: session.setHold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCastPicker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1E),
        title:
            const Text('Diffuser vers', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 320,
          child: StreamBuilder<List<CastRoute>>(
            stream: session.cast.routes,
            builder: (context, snap) {
              final routes = snap.data ?? const <CastRoute>[];
              if (routes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Recherche de TV…',
                      style: TextStyle(color: Colors.white70)),
                );
              }
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final r in routes)
                    ListTile(
                      leading: const Icon(Icons.tv, color: Colors.white70),
                      title: Text(r.name,
                          style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        session.cast.connect(r.id);
                        Navigator.pop(context);
                      },
                    ),
                  if (session.cast.state == CastState.connected)
                    ListTile(
                      leading: const Icon(Icons.close, color: Colors.white70),
                      title: const Text('Arrêter la diffusion',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        session.cast.disconnect();
                        Navigator.pop(context);
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Calibration du décalage son/visuel : négatif = avancer les visuels
/// (latence de capture micro), positif = les retarder (enceinte Bluetooth).
class _SyncFader extends StatelessWidget {
  final Session session;
  const _SyncFader({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('SYNC',
            style: TextStyle(
                color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
        SizedBox(
          width: 130,
          child: ValueListenableBuilder(
            valueListenable: session.offsetMs,
            builder: (_, v, _) => Slider(
              value: v.toDouble(),
              min: -300,
              max: 300,
              divisions: 60,
              onChanged: (x) => session.setOffsetMs(x.round()),
              activeColor: const Color(0xFFFFB547),
              inactiveColor: Colors.white24,
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: session.offsetMs,
          builder: (_, v, _) => SizedBox(
            width: 52,
            child: Text('$v ms',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ),
      ],
    );
  }
}

class _Fader extends StatelessWidget {
  final String label;
  final ValueNotifier<double> listenable;
  final ValueChanged<double> onChanged;
  const _Fader(
      {required this.label, required this.listenable, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
        SizedBox(
          width: 110,
          child: ValueListenableBuilder(
            valueListenable: listenable,
            builder: (_, v, _) => Slider(
              value: v,
              onChanged: onChanged,
              activeColor: const Color(0xFFFFB547),
              inactiveColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

class _TriggerButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _TriggerButton(this.label, {required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 34),
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(fontSize: 11, letterSpacing: 1.2)),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  final String text;
  const _InfoText(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      );
}

class _LevelBars extends StatelessWidget {
  final Levels levels;
  const _LevelBars({required this.levels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in [levels.low, levels.mid, levels.high])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: SizedBox(
              width: 6,
              height: 26,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 26 * v.clamp(0.05, 1.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB547),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
