import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'audio/audio_analyzer.dart';
import 'autopilot/autopilot.dart';
import 'autopilot/presets.dart';
import 'cast/cast_link.dart';
import 'config.dart';
import 'engine/engine_link.dart';
import 'engine/local_link.dart';
import 'sources/clip_catalog.dart';
import 'sources/pixabay.dart';
import 'sources/sources_model.dart';

/// BPM de secours quand l'analyse ne détecte rien (silence, ambiance sans
/// pulsation nette, premières secondes de signal) : 120 BPM, la moyenne
/// usuelle de la musique populaire. Mesure de 2 s ancrée sur l'horloge epoch :
/// deux messages de secours successifs décrivent la même grille, donc pas de
/// saut de phase côté moteur. Confiance 0 — la vraie détection reprend la
/// main dès qu'elle verrouille.
const double kFallbackBpm = 120;

BeatEstimate withFallbackBpm(BeatEstimate b) {
  if (b.bpm > 0) return b;
  const measureMs = 4 * 60000 / kFallbackBpm; // 2000 ms
  final phase = (b.t0 % measureMs) / measureMs;
  return BeatEstimate(kFallbackBpm, phase, b.t0, 0);
}

/// Session jalon 2 : micro -> analyse -> autopilote -> moteur(s).
/// Le même flux de messages part vers le moteur local (WebView sur mobile,
/// iframe en préviz web) et, si connecté, vers le Chromecast.
class Session {
  // Les navigateurs capturent quasi systématiquement à 48 kHz.
  final analyzer = AudioAnalyzer(sampleRate: kIsWeb ? 48000 : 44100);
  final local = createLocalLink();
  final cast = CastLink();
  final _recorder = AudioRecorder();
  late final Autopilot pilot;

  final bpm = ValueNotifier<double>(0);
  final confidence = ValueNotifier<double>(0);
  final levels = ValueNotifier<Levels>(const Levels(0, 0, 0));
  final structure = ValueNotifier<StructureState>(StructureState.steady);
  final micOk = ValueNotifier<bool?>(null);
  final castState = ValueNotifier<CastState>(CastState.idle);
  final stats = ValueNotifier<String>('—');
  final latency = ValueNotifier<String>('—');
  final energy = ValueNotifier<double>(0.5);
  final light = ValueNotifier<double>(0.5);

  /// Crans choisis sur les rotacteurs (ids de presets.dart). Seuls
  /// Retrofutur × Cosmos ont un preset moteur au jalon 3.
  final styleId = ValueNotifier<String>('retrofutur');
  final universeId = ValueNotifier<String>('cosmos');

  /// Sources vidéo de la session (données factices au jalon 3).
  final sourcesModel = SourcesModel();

  /// Surimpression caméra (bouton à côté des effets) : affichée par-dessus le
  /// fond avec l'opacité du fader. Moteur LOCAL uniquement : en diffusion, le
  /// Chromecast n'a pas accès à la caméra du téléphone (streaming au jalon 5+).
  final cameraShown = ValueNotifier<bool>(false);
  final cameraOpacity = ValueNotifier<double>(0.75);

  /// Fonds Pixabay par univers (jalon 4). Sans clé : shaders seuls.
  final PixabayClient? _pixabay =
      pixabayKey.isEmpty ? null : PixabayClient(pixabayKey);

  /// Catalogue hébergé (extraits FedFlix + boucles VJ). Chargé une fois.
  CatalogData _catalog = CatalogData.empty;
  List<PixabayClip> _pixabayClips = const [];
  int _lightBucket = -1;

  /// Vrai une fois start() exécuté (bouton Lancer).
  bool get started => _started;
  bool _started = false;

  /// Décalage de calibration en ms. Négatif = avancer les visuels (compense
  /// la latence de capture micro), positif = les retarder (son du téléphone
  /// sur enceinte Bluetooth, cf. brief). Calibration auto au jalon 2b.
  // +70 ms : calibré à l'oreille en préviz Chrome (2026-09-25, estimateur
  // tempogramme). À recalibrer sur téléphone au jalon 2b.
  final offsetMs = ValueNotifier<int>(kIsWeb ? 70 : 0);

  /// Barre de calibration du moteur (flash sur chaque temps extrapolé).
  /// Servait aux tests des jalons 1-2 ; désactivée par défaut depuis le
  /// jalon 3 (réutilisable pour la calibration auto du jalon 2b).
  final beatBar = ValueNotifier<bool>(false);
  BeatEstimate? _lastBeat;
  bool debug = true;

  final List<StreamSubscription> _subs = [];
  Timer? _pingTimer;

  Session() {
    pilot = Autopilot(style: retrofutur, universe: cosmos, send: _sendAll);
    // Catalogue des presets : chargé en tâche de fond, puis réappliqué pour
    // que les crans choisis avant le chargement prennent effet.
    PresetCatalog.load().then((_) {
      pilot.setStyle(stylePresetFor(styleId.value));
      pilot.setUniverse(universePresetFor(universeId.value));
      _loadClips(universeId.value);
    });
    ClipCatalog.load(catalogUrl).then((data) {
      _catalog = data;
      _pushPool(universeId.value);
    });
  }

  /// Charge les clips Pixabay de l'univers puis reconstruit le pool,
  /// sauf si l'utilisateur a déjà changé d'univers entre-temps.
  Future<void> _loadClips(String id) async {
    _pixabayClips = const [];
    _pushPool(id);
    final client = _pixabay;
    if (client == null) return;
    final queries = universePresetFor(id).queries;
    if (queries.isEmpty) return;
    final clips = await clipsForQueries(client, queries);
    if (universeId.value == id) {
      _pixabayClips = clips;
      _pushPool(id);
    }
  }

  /// Pool de clips de l'autopilote : Pixabay de l'univers + catalogue
  /// hébergé filtré par univers et par lumière (règle du brief).
  void _pushPool(String universeId) {
    final light = this.light.value;
    pilot.setClips([
      ..._pixabayClips,
      ..._catalog.clips.where(
          (c) => c.univers == universeId && clipMatchesLight(c, light)),
    ]);
  }

  List<EngineLink> get _links => [
        local,
        if (cast.state == CastState.connected) cast,
      ];

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subs.add(analyzer.levels.listen((l) {
      levels.value = l;
      _sendAll({'type': 'levels', 'low': l.low, 'mid': l.mid, 'high': l.high});
    }));
    _subs.add(analyzer.beats.listen((raw) {
      final b = withFallbackBpm(raw);
      bpm.value = b.bpm;
      confidence.value = b.confidence;
      pilot.onBeat(b);
      _lastBeat = b;
      _sendBeat(b);
    }));
    _subs.add(analyzer.structures.listen((s) {
      structure.value = s;
      pilot.onStructure(s);
    }));
    _subs.add(cast.states.listen((s) {
      castState.value = s;
      if (s == CastState.connected) {
        // Le receiver démarre muet : on lui pousse l'état courant complet.
        cast.send({
          'type': 'config',
          'debug': debug,
          'beatBar': beatBar.value,
          'energy': pilot.energy,
          'light': pilot.light,
        });
      }
    }));

    for (final link in [local, cast]) {
      link.onFeedback = (msg) {
        if (msg['type'] == 'stats') {
          final src = link == cast ? 'TV' : 'local';
          stats.value =
              '$src ${msg['fps']} i/s · ${msg['renderMs']} ms · ${msg['bg']}';
        } else if (msg['type'] == 'bgerror') {
          debugPrint('Fond vidéo illisible : ${msg['id']} (${msg['reason']})');
          if (msg['id'] == 'camera') {
            // Caméra refusée ou absente : le bouton se relâche.
            cameraShown.value = false;
          } else {
            // Clip illisible : banni pour la session, scène remplacée.
            pilot.banOnError(msg['id'] as String);
          }
        }
      };
    }

    local.send({'type': 'config', 'debug': debug, 'beatBar': beatBar.value});
    pilot.start();
    setEnergy(energy.value);
    setLight(light.value);

    // Latence aller-retour mesurée toutes les 2 s sur le lien actif.
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final link = cast.state == CastState.connected ? cast : local;
      final label = link == cast ? 'TV' : 'local';
      try {
        final rtt = await link.ping();
        latency.value = '$label ${(rtt.inMilliseconds / 2).round()} ms';
      } on Object {
        latency.value = '$label —';
      }
    });

    try {
      if (await _recorder.hasPermission()) {
        final stream = await _recorder.startStream(RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: analyzer.sampleRate,
          numChannels: 1,
        ));
        _subs.add(stream.listen(analyzer.addPcm16));
        micOk.value = true;
      } else {
        micOk.value = false;
      }
    } catch (e) {
      debugPrint('Micro indisponible : $e');
      micOk.value = false;
    }
  }

  /// Bouton caméra (à côté des effets) : affiche/masque la caméra de
  /// l'appareil en surimpression du fond (webcam en préviz PC, objectif
  /// arrière sur téléphone), fondu géré par le moteur.
  void toggleCamera() => setCameraShown(!cameraShown.value);

  void setCameraShown(bool v) {
    cameraShown.value = v;
    local.send({
      'type': 'config',
      'camera': v,
      'cameraOpacity': cameraOpacity.value,
    });
  }

  /// Fader d'opacité de la surimpression caméra.
  void setCameraOpacity(double v) {
    cameraOpacity.value = v;
    if (cameraShown.value) {
      local.send({'type': 'config', 'cameraOpacity': v});
    }
  }

  void _sendAll(Map<String, dynamic> msg) {
    for (final link in _links) {
      link.send(msg);
    }
  }

  void _sendBeat(BeatEstimate b) {
    _sendAll({
      'type': 'beat',
      'bpm': b.bpm,
      'phase': b.phase,
      't0': b.t0,
      'offsetMs': offsetMs.value,
      'confidence': b.confidence,
    });
  }

  void setOffsetMs(int v) {
    offsetMs.value = v;
    // Réapplique immédiatement le décalage sans attendre le prochain beat.
    if (_lastBeat case final b?) _sendBeat(b);
  }

  void setEnergy(double v) {
    energy.value = v;
    pilot.setEnergy(v);
  }

  void setLight(double v) {
    light.value = v;
    pilot.setLight(v);
    // Re-filtre le catalogue par tranche de lumière (évite de reconstruire
    // le pool à chaque cran du fader).
    final bucket = (v * 3).round();
    if (bucket != _lightBucket) {
      _lightBucket = bucket;
      _pushPool(universeId.value);
    }
  }

  void flash() => pilot.triggerFlash();

  /// Effets maintenables de la console (strobe, negative, zoom, shake, echo,
  /// rewind) : on à l'appui, off au relâchement. La quantification (tap = une
  /// mesure complète) est gérée côté moteur (voir PROTOCOL.md).
  void fxDown(String id) => _sendAll({'type': 'trigger', 'id': id, 'on': true});
  void fxUp(String id) => _sendAll({'type': 'trigger', 'id': id, 'on': false});

  /// Durée du burst d'un tap d'effet (une mesure de 4 temps ; 2 s sans beat,
  /// même règle que le moteur) — sert aux voyants des boutons.
  Duration get fxBurst => bpm.value > 0
      ? Duration(milliseconds: (4 * 60000 / bpm.value).round())
      : const Duration(seconds: 2);

  void setStyle(String id) {
    styleId.value = id;
    pilot.setStyle(stylePresetFor(id));
  }

  void setUniverse(String id) {
    universeId.value = id;
    pilot.setUniverse(universePresetFor(id));
    _loadClips(id);
  }

  /// Phase du temps courant [0,1) pour la LED tempo, calée sur l'horloge de
  /// détection (pas sur un timer libre).
  double beatPhase() => (pilot.clock.measurePhase() * 4) % 1;

  void setDebug(bool value) {
    debug = value;
    _sendAll({'type': 'config', 'debug': value});
  }

  void setBeatBar(bool value) {
    beatBar.value = value;
    _sendAll({'type': 'config', 'beatBar': value});
  }

  Future<void> dispose() async {
    _pingTimer?.cancel();
    pilot.stop();
    sourcesModel.dispose();
    for (final s in _subs) {
      await s.cancel();
    }
    await _recorder.stop();
    await _recorder.dispose();
    analyzer.dispose();
    cast.dispose();
    _pixabay?.dispose();
  }
}
