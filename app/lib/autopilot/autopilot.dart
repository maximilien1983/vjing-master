import 'dart:async';
import 'dart:math';

import '../audio/audio_analyzer.dart';
import 'beat_clock.dart';
import 'presets.dart';

/// Règles du brief implémentées ici :
/// - changement de fond toutes les 32 (énergie 0) à 4 (énergie 100) mesures ;
/// - 0 à 4 boucles superposées selon l'énergie, apparition/disparition en fondu ;
/// - intensité des filtres 20 % à 100 % ;
/// - historique des 10 derniers fonds, bannis de session (Suivant) ;
/// - transitions quantifiées sur la mesure ; sans beat : dérive lente ;
/// - montée détectée : changements resserrés ; drop : tout au maximum 4 mesures ;
/// - Garder : fige la scène ; Scène : nouveau fond + boucles au prochain temps 1.

double changeIntervalMeasures(double energy, StructureState structure) {
  var interval = 32 - 28 * energy.clamp(0.0, 1.0); // 32 -> 4
  switch (structure) {
    case StructureState.rise:
      interval /= 2;
    case StructureState.calm:
      interval *= 1.5;
    case StructureState.drop:
    case StructureState.steady:
      break;
  }
  return interval.clamp(2, 48);
}

int overlayTarget(double energy, StructureState structure) {
  var n = (energy.clamp(0.0, 1.0) * 4).round();
  if (structure == StructureState.drop) n += 1;
  return n.clamp(0, 4);
}

double filterIntensity(double energy, StructureState structure) {
  if (structure == StructureState.drop) return 1.0;
  return 0.2 + 0.8 * energy.clamp(0.0, 1.0);
}

/// Choisit un fond hors historique récent et hors bannis. Si tout est épuisé,
/// l'historique est ignoré (mais jamais les bannis, sauf s'il ne reste rien).
String selectBackground(
  Random rng,
  List<String> available,
  List<String> history,
  Set<String> banned,
) {
  final notBanned = available.where((b) => !banned.contains(b)).toList();
  final pool = notBanned.isEmpty ? available : notBanned;
  final recent = history.length > pool.length - 1
      ? history.sublist(history.length - (pool.length - 1).clamp(0, history.length))
      : history;
  final fresh = pool.where((b) => !recent.contains(b)).toList();
  final candidates = fresh.isEmpty ? pool : fresh;
  return candidates[rng.nextInt(candidates.length)];
}

class OverlayState {
  final String iid;
  final String motif;
  final double x, y, scale, rot, pulse;
  const OverlayState(this.iid, this.motif, this.x, this.y, this.scale, this.rot, this.pulse);

  Map<String, dynamic> toJson() =>
      {'iid': iid, 'motif': motif, 'x': x, 'y': y, 'scale': scale, 'rot': rot, 'pulse': pulse};
}

class Autopilot {
  final StylePreset style;
  final UniversePreset universe;
  final Random rng;
  final void Function(Map<String, dynamic> msg) send;

  final clock = BeatClock();
  final List<String> history = [];
  final Set<String> banned = {};

  double energy = 0.5;
  double light = 0.5;
  StructureState structure = StructureState.steady;
  bool hold = false; // Garder

  String? _currentBg;
  final List<OverlayState> _overlays = [];
  int _nextChangeMeasure = 0;
  int _nextOverlayDriftMeasure = 0;
  int _overlaySeq = 0;
  int _dropUntilMeasure = -1;
  bool _sceneRequested = false;
  Timer? _ticker;

  Autopilot({
    required this.style,
    required this.universe,
    required this.send,
    Random? rng,
  }) : rng = rng ?? Random();

  void start() {
    _pushScene(cut: true);
    _scheduleNextChange();
    // Tick court : la quantification se fait sur l'horloge de mesure, pas sur
    // la période du timer.
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void onBeat(BeatEstimate e) => clock.update(e);

  void onStructure(StructureState s) {
    structure = s;
    if (s == StructureState.drop && !hold) {
      // Montée brutale détectée dans la musique : même effet que le bouton Drop.
      triggerDrop();
    }
  }

  void setEnergy(double v) {
    energy = v.clamp(0.0, 1.0);
    send({'type': 'config', 'energy': energy});
    _pushScene(); // met à jour filtres et nombre de boucles en douceur
    _scheduleNextChange();
  }

  void setLight(double v) {
    light = v.clamp(0.0, 1.0);
    send({'type': 'config', 'light': light});
  }

  void setHold(bool v) {
    hold = v;
  }

  /// Suivant : zappe le fond en cours et l'écarte pour la session.
  void triggerNext() {
    if (_currentBg != null) banned.add(_currentBg!);
    _changeBackground();
    _pushScene();
    _scheduleNextChange();
  }

  /// Scène : nouveau fond et nouvelles boucles au prochain temps 1.
  void triggerScene() {
    _sceneRequested = true;
  }

  /// Drop : coupe au noir (moteur), puis tout au maximum pendant 4 mesures.
  void triggerDrop() {
    send({'type': 'trigger', 'id': 'drop'});
    _dropUntilMeasure = clock.measureCount + 4;
    _changeBackground();
    _rebuildOverlays(4);
    _pushScene();
    _scheduleNextChange();
  }

  void triggerFlash() {
    send({'type': 'trigger', 'id': 'flash'});
  }

  void _tick() {
    final boundary = clock.tickMeasureBoundary();
    if (!boundary) return;
    if (hold) return; // Garder : la scène est figée

    final m = clock.measureCount;
    if (_dropUntilMeasure >= 0 && m >= _dropUntilMeasure) {
      _dropUntilMeasure = -1; // retour progressif : la scène suivante retombe
      _pushScene();
    }
    if (_sceneRequested) {
      _sceneRequested = false;
      _changeBackground();
      _rebuildOverlays(overlayTarget(energy, structure));
      _pushScene();
      _scheduleNextChange();
      return;
    }
    if (m >= _nextChangeMeasure) {
      _changeBackground();
      _pushScene();
      _scheduleNextChange();
    } else if (m >= _nextOverlayDriftMeasure) {
      // Dérive douce : on remplace ou déplace une boucle sans toucher au fond.
      _driftOverlays();
      _pushScene();
      _nextOverlayDriftMeasure = m + 2;
    }
  }

  void _scheduleNextChange() {
    final interval = changeIntervalMeasures(energy, structure).round();
    _nextChangeMeasure = clock.measureCount + interval;
    _nextOverlayDriftMeasure = clock.measureCount + 2;
  }

  void _changeBackground() {
    final bg = selectBackground(rng, universe.backgrounds, history, banned);
    _currentBg = bg;
    history.add(bg);
    if (history.length > 10) history.removeAt(0);
  }

  OverlayState _randomOverlay() {
    final motif = universe.motifs[rng.nextInt(universe.motifs.length)];
    return OverlayState(
      'o${_overlaySeq++}',
      motif,
      (rng.nextDouble() - 0.5) * 1.2,
      (rng.nextDouble() - 0.5) * 1.0,
      0.3 + rng.nextDouble() * 0.35,
      (rng.nextDouble() - 0.5) * 1.2,
      0.3 + 0.7 * energy,
    );
  }

  void _rebuildOverlays(int count) {
    _overlays.clear();
    for (var i = 0; i < count; i++) {
      _overlays.add(_randomOverlay());
    }
  }

  void _driftOverlays() {
    final target = _dropUntilMeasure >= 0 ? 4 : overlayTarget(energy, structure);
    while (_overlays.length > target) {
      _overlays.removeAt(rng.nextInt(_overlays.length));
    }
    while (_overlays.length < target) {
      _overlays.add(_randomOverlay());
    }
    // Remplace une boucle de temps en temps pour que ça vive.
    if (_overlays.isNotEmpty && rng.nextDouble() < 0.4) {
      _overlays[rng.nextInt(_overlays.length)] = _randomOverlay();
    }
  }

  void _pushScene({bool cut = false}) {
    _currentBg ??= selectBackground(rng, universe.backgrounds, history, banned);
    if (history.isEmpty) history.add(_currentBg!);
    final dropping = _dropUntilMeasure >= 0;
    final intensity = filterIntensity(energy, dropping ? StructureState.drop : structure);
    send({
      'type': 'scene',
      'state': {
        'background': {'kind': 'shader', 'id': _currentBg},
        'overlays': [for (final o in _overlays) o.toJson()],
        'filters': [
          for (final id in style.filterIds) {'id': id, 'intensity': intensity},
        ],
        'transition': {
          'kind': cut ? 'cut' : style.transitionKind,
          'beats': clock.hasBeat ? style.transitionBeats : 8,
        },
      },
    });
  }
}
