import 'dart:async';
import 'dart:math';

import '../audio/audio_analyzer.dart';
import '../sources/clips.dart';
import 'beat_clock.dart';
import 'presets.dart';

/// Règles du brief implémentées ici :
/// - changement de fond toutes les 32 (énergie 0) à 4 (énergie 100) mesures ;
/// - 0 à 4 boucles superposées selon l'énergie, apparition/disparition en fondu ;
/// - intensité des filtres 20 % à 100 % ;
/// - historique des 10 derniers fonds (variété) ; bannis de session sur erreur ;
/// - transitions quantifiées sur la mesure ; sans beat : dérive lente ;
/// - montée détectée : changements resserrés ; drop : tout au maximum 4 mesures.
/// Les effets ponctuels des boutons (strobe, echo…) sont gérés par le moteur
/// (voir renderer/PROTOCOL.md), pas ici.

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
  final String? motif; // motif shader, null pour une boucle vidéo
  final String? url; // boucle vidéo (motif lumineux sur fond noir)
  final double x, y, scale, rot, pulse;
  const OverlayState(this.iid, this.motif, this.x, this.y, this.scale, this.rot, this.pulse)
      : url = null;
  const OverlayState.video(this.iid, this.url, this.x, this.y, this.scale, this.rot, this.pulse)
      : motif = null;

  bool get isVideo => url != null;

  Map<String, dynamic> toJson() => {
        'iid': iid,
        if (isVideo) 'kind': 'video',
        if (isVideo) 'url': url,
        if (!isVideo) 'motif': motif,
        'x': x,
        'y': y,
        'scale': scale,
        'rot': rot,
        'pulse': pulse,
      };
}

class Autopilot {
  StylePreset style;
  UniversePreset universe;
  final Random rng;
  final void Function(Map<String, dynamic> msg) send;

  final clock = BeatClock();
  final List<String> history = [];
  final Set<String> banned = {};

  double energy = 0.5;
  double light = 0.5;
  StructureState structure = StructureState.steady;

  String? _currentBg;
  final Map<String, String> _clipUrls = {}; // id de clip -> URL (kind video)
  List<EngineClip> _loops = []; // boucles VJ du style courant
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
    if (s == StructureState.drop) {
      // Montée brutale détectée dans la musique : coupe au noir puis tout au
      // maximum pendant 4 mesures.
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

  /// Changement de style : les filtres et transitions suivent immédiatement.
  void setStyle(StylePreset s) {
    if (s.id == style.id) return;
    style = s;
    _pushScene();
  }

  /// Changement d'univers : nouveau bassin de fonds et de motifs, nouvelle
  /// scène quantifiée au prochain temps 1 (comme le bouton Scène).
  void setUniverse(UniversePreset u) {
    if (u.id == universe.id) return;
    universe = u;
    history.clear();
    banned.clear();
    // Les clips de l'ancien univers ne doivent plus être piochés ; la session
    // pousse ceux du nouveau dès qu'ils sont chargés.
    setClips(const []);
    _sceneRequested = true;
  }

  /// Clips vidéo de l'univers courant (Pixabay, catalogue FedFlix…),
  /// fusionnés aux fonds shaders dans le tirage.
  void setClips(List<EngineClip> clips) {
    _clipUrls
      ..clear()
      ..addEntries(clips.map((c) => MapEntry(c.id, c.url)));
  }

  /// Boucles VJ du style courant (motifs vidéo, fusion additive), mélangées
  /// aux motifs shaders. Une seule boucle vidéo à l'écran à la fois : le
  /// budget de décodage du moteur privilégie les fonds (2 vidéos max).
  void setLoops(List<EngineClip> loops) {
    _loops = loops;
  }

  /// Fond illisible côté moteur (réseau, CORS…) : banni pour la session,
  /// et remplacé immédiatement s'il est à l'écran.
  void banOnError(String id) {
    banned.add(id);
    if (_currentBg == id) {
      _changeBackground();
      _pushScene();
      _scheduleNextChange();
    }
  }

  List<String> get _bgPool => [...universe.backgrounds, ..._clipUrls.keys];

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
    final bg = selectBackground(rng, _bgPool, history, banned);
    _currentBg = bg;
    history.add(bg);
    if (history.length > 10) history.removeAt(0);
  }

  bool get _hasVideoOverlay => _overlays.any((o) => o.isVideo);

  OverlayState _randomOverlay({bool allowVideo = true}) {
    final iid = 'o${_overlaySeq++}';
    final x = (rng.nextDouble() - 0.5) * 1.2;
    final y = (rng.nextDouble() - 0.5) * 1.0;
    final rot = (rng.nextDouble() - 0.5) * 1.2;
    final pulse = 0.3 + 0.7 * energy;
    // Une chance sur deux de piocher une boucle vidéo quand c'est permis.
    if (allowVideo && _loops.isNotEmpty && rng.nextBool()) {
      final loop = _loops[rng.nextInt(_loops.length)];
      return OverlayState.video(
          iid, loop.url, x, y, 0.45 + rng.nextDouble() * 0.35, rot * 0.3, pulse);
    }
    // Les motifs appartiennent au style (brief « Paramètres »).
    final motif = style.motifs[rng.nextInt(style.motifs.length)];
    return OverlayState(
        iid, motif, x, y, 0.3 + rng.nextDouble() * 0.35, rot, pulse);
  }

  void _rebuildOverlays(int count) {
    _overlays.clear();
    for (var i = 0; i < count; i++) {
      _overlays.add(_randomOverlay(allowVideo: !_hasVideoOverlay));
    }
  }

  void _driftOverlays() {
    final target = _dropUntilMeasure >= 0 ? 4 : overlayTarget(energy, structure);
    while (_overlays.length > target) {
      _overlays.removeAt(rng.nextInt(_overlays.length));
    }
    while (_overlays.length < target) {
      _overlays.add(_randomOverlay(allowVideo: !_hasVideoOverlay));
    }
    // Remplace une boucle de temps en temps pour que ça vive.
    if (_overlays.isNotEmpty && rng.nextDouble() < 0.4) {
      final i = rng.nextInt(_overlays.length);
      final allowVideo = _overlays[i].isVideo || !_hasVideoOverlay;
      _overlays[i] = _randomOverlay(allowVideo: allowVideo);
    }
  }

  void _pushScene({bool cut = false}) {
    _currentBg ??= selectBackground(rng, _bgPool, history, banned);
    if (history.isEmpty) history.add(_currentBg!);
    final dropping = _dropUntilMeasure >= 0;
    final intensity = filterIntensity(energy, dropping ? StructureState.drop : structure);
    final clipUrl = _clipUrls[_currentBg];
    send({
      'type': 'scene',
      'state': {
        'background': clipUrl != null
            ? {'kind': 'video', 'id': _currentBg, 'url': clipUrl}
            : {'kind': 'shader', 'id': _currentBg},
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
