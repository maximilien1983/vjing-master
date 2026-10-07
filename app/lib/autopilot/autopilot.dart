import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../audio/audio_analyzer.dart';
import '../sources/clips.dart';
import 'beat_clock.dart';
import 'presets.dart';

/// Règles du brief implémentées ici :
/// - changement de fond toutes les 32 (énergie 0) à 4 (énergie 100) mesures ;
/// - effets vidéo séquencés (décision 2026-10-07, remplace les motifs
///   superposés jugés cheap) : plusieurs filtres par style, intensités et
///   pulsations sur le beat aléatoires, enchaînés, avec des pauses ;
/// - l'univers rend les effets plus ou moins marqués (fxGain) et y mêle ses
///   filtres signatures (fxIds) ;
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

/// Effet vidéo actif : filtre du moteur + intensité de base + pulsation sur
/// le beat (appliquée image par image côté moteur, voir PROTOCOL.md).
class FxStep {
  final String id;
  final double intensity; // 0..1
  final double pulse; // 0 = constant, 1 = ne vit que sur les temps
  const FxStep(this.id, this.intensity, this.pulse);
}

class Autopilot {
  /// Fond caméra (id réservé du protocole) : caméra de l'appareil côté
  /// moteur — webcam en préviz PC, objectif arrière sur téléphone.
  static const cameraBgId = 'camera';

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
  bool _cameraOn = false;
  bool _cameraPinned = false;
  final Map<String, String> _clipUrls = {}; // id de clip -> URL (kind video)
  List<FxStep> _fx = const [];
  int _nextFxMeasure = 0;
  int _nextChangeMeasure = 0;
  int _dropUntilMeasure = -1;
  bool _sceneRequested = false;
  Timer? _ticker;

  Autopilot({
    required this.style,
    required this.universe,
    required this.send,
    Random? rng,
  }) : rng = rng ?? Random();

  /// Effets vidéo actifs (lecture seule, pour les tests).
  List<FxStep> get activeFx => List.unmodifiable(_fx);

  void start() {
    _mutateFx(allowPause: false);
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
    _pushScene(); // réapplique la scène courante en douceur
    _scheduleNextChange();
  }

  void setLight(double v) {
    light = v.clamp(0.0, 1.0);
    send({'type': 'config', 'light': light});
  }

  /// Changement de style : nouveau bassin d'effets, appliqué immédiatement.
  void setStyle(StylePreset s) {
    if (s.id == style.id) return;
    style = s;
    _mutateFx(allowPause: false);
    _pushScene();
  }

  /// Changement d'univers : nouveau bassin de fonds et d'effets, nouvelle
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

  /// Source caméra chargée/déchargée (écran Sources). Chargée : elle entre
  /// dans le bassin de fonds comme un clip. Déchargée : plus jamais piochée,
  /// et si elle est à l'écran (rotation ou bouton caméra) on la remplace.
  void setCamera(bool on) {
    _cameraOn = on;
    if (!on && _currentBg == cameraBgId) {
      _cameraPinned = false;
      _changeBackground();
      _pushScene();
      _scheduleNextChange();
    }
  }

  /// Bouton caméra de la console : affiche la caméra et la MAINTIENT à
  /// l'écran (les changements de fond sont suspendus) jusqu'au masquage.
  /// Indépendant du bassin : marche même source non chargée, et retenter
  /// après un refus de permission est permis (dé-bannie au passage).
  /// Caméra indisponible ⇒ le moteur envoie `bgerror`, banOnError libère.
  void setCameraPinned(bool v) {
    if (v == _cameraPinned) return;
    _cameraPinned = v;
    if (v) {
      banned.remove(cameraBgId);
      _currentBg = cameraBgId;
      history.add(cameraBgId);
      if (history.length > 10) history.removeAt(0);
      _pushScene();
      _scheduleNextChange();
    } else if (_currentBg == cameraBgId) {
      _changeBackground();
      _pushScene();
      _scheduleNextChange();
    }
  }

  /// Fond illisible côté moteur (réseau, CORS…) : banni pour la session,
  /// et remplacé immédiatement s'il est à l'écran.
  void banOnError(String id) {
    banned.add(id);
    if (id == cameraBgId) _cameraPinned = false;
    if (_currentBg == id) {
      _changeBackground();
      _pushScene();
      _scheduleNextChange();
    }
  }

  List<String> get _bgPool => [
        ...universe.backgrounds,
        ..._clipUrls.keys,
        if (_cameraOn) cameraBgId,
      ];

  /// Bassin d'effets : filtres du style (plusieurs par cran EFFECTS) + les
  /// filtres signatures de l'univers.
  List<String> get _fxPool => {...style.filterIds, ...universe.fxIds}.toList();

  /// Drop : coupe au noir (moteur), puis tout au maximum pendant 4 mesures.
  void triggerDrop() {
    send({'type': 'trigger', 'id': 'drop'});
    _dropUntilMeasure = clock.measureCount + 4;
    _changeBackground();
    _mutateFx(allowPause: false);
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
      _dropUntilMeasure = -1; // retour progressif : les effets retombent
      _mutateFx(allowPause: false);
      _pushScene();
    }
    if (_sceneRequested) {
      _sceneRequested = false;
      _changeBackground();
      _mutateFx(allowPause: false);
      _pushScene();
      _scheduleNextChange();
      return;
    }
    if (m >= _nextChangeMeasure) {
      _changeBackground();
      _pushScene();
      _scheduleNextChange();
    } else if (m >= _nextFxMeasure) {
      // Les effets vivent leur vie entre deux changements de fond.
      _mutateFx();
      _pushScene();
    }
  }

  void _scheduleNextChange() {
    final interval = changeIntervalMeasures(energy, structure).round();
    _nextChangeMeasure = clock.measureCount + interval;
  }

  void _changeBackground() {
    // Caméra maintenue par le bouton de la console : le fond ne tourne pas.
    if (_cameraPinned) return;
    final bg = selectBackground(rng, _bgPool, history, banned);
    _currentBg = bg;
    history.add(bg);
    if (history.length > 10) history.removeAt(0);
  }

  /// Fait vivre les effets vidéo (décision 2026-10-07) : tirage de 1 à 3
  /// filtres du bassin, intensités et pulsations sur le beat aléatoires,
  /// enchaînés toutes les 1 à 6 mesures (resserré par l'énergie), avec
  /// parfois une pause d'une à trois mesures sans aucun effet. L'univers
  /// les rend plus ou moins marqués (fxGain). Pendant un drop : tout au
  /// maximum, pulsation forte.
  void _mutateFx({bool allowPause = true}) {
    final dropping = _dropUntilMeasure >= 0;
    if (allowPause && !dropping && _fx.isNotEmpty && rng.nextDouble() < 0.18) {
      _fx = const [];
      _nextFxMeasure = clock.measureCount + 1 + rng.nextInt(3);
      return;
    }
    final pool = _fxPool..shuffle(rng);
    final maxN = min(3, pool.length);
    final count = dropping ? maxN : 1 + rng.nextInt(maxN);
    // « Plus ou moins marqués » : plancher d'ambiance à énergie 0, plein
    // régime à 100, le tout teinté par le gain de l'univers.
    final strength = ((0.35 + 0.65 * energy) * universe.fxGain).clamp(0.0, 1.0);
    _fx = [
      for (final id in pool.take(count))
        FxStep(
          id,
          dropping
              ? 1.0
              : ((0.35 + 0.65 * rng.nextDouble()) * strength).clamp(0.1, 1.0),
          dropping ? 0.8 : 0.2 + 0.8 * rng.nextDouble(),
        ),
    ];
    final span =
        dropping ? 2 : 1 + rng.nextInt(max(1, (6 - 4 * energy).round()));
    _nextFxMeasure = clock.measureCount + span;
  }

  @visibleForTesting
  void debugMutateFx({bool allowPause = true}) =>
      _mutateFx(allowPause: allowPause);

  void _pushScene({bool cut = false}) {
    _currentBg ??= selectBackground(rng, _bgPool, history, banned);
    if (history.isEmpty) history.add(_currentBg!);
    final clipUrl = _clipUrls[_currentBg];
    send({
      'type': 'scene',
      'state': {
        'background': _currentBg == cameraBgId
            ? {'kind': 'camera', 'id': cameraBgId}
            : clipUrl != null
                ? {'kind': 'video', 'id': _currentBg, 'url': clipUrl}
                : {'kind': 'shader', 'id': _currentBg},
        // Plus de motifs superposés (2026-10-07) : les effets vidéo séquencés
        // les remplacent. Le moteur les supporte toujours (bancs d'essai).
        'overlays': const [],
        'filters': [
          for (final f in _fx)
            {'id': f.id, 'intensity': f.intensity, 'pulse': f.pulse},
        ],
        'transition': {
          'kind': cut ? 'cut' : style.transitionKind,
          'beats': clock.hasBeat ? style.transitionBeats : 8,
        },
      },
    });
  }
}
