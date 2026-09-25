import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'audio/audio_analyzer.dart';
import 'autopilot/autopilot.dart';
import 'autopilot/presets.dart';
import 'cast/cast_link.dart';
import 'engine/engine_link.dart';
import 'engine/local_link.dart';

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
  final hold = ValueNotifier<bool>(false);

  /// Décalage de calibration en ms. Négatif = avancer les visuels (compense
  /// la latence de capture micro), positif = les retarder (son du téléphone
  /// sur enceinte Bluetooth, cf. brief). Calibration auto au jalon 2b.
  final offsetMs = ValueNotifier<int>(kIsWeb ? -120 : 0);
  BeatEstimate? _lastBeat;
  bool debug = true;

  final List<StreamSubscription> _subs = [];
  Timer? _pingTimer;

  Session() {
    pilot = Autopilot(style: retrofutur, universe: cosmos, send: _sendAll);
  }

  List<EngineLink> get _links => [
        local,
        if (cast.state == CastState.connected) cast,
      ];

  Future<void> start() async {
    _subs.add(analyzer.levels.listen((l) {
      levels.value = l;
      _sendAll({'type': 'levels', 'low': l.low, 'mid': l.mid, 'high': l.high});
    }));
    _subs.add(analyzer.beats.listen((b) {
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
        cast.send({'type': 'config', 'debug': debug, 'energy': pilot.energy, 'light': pilot.light});
      }
    }));

    for (final link in [local, cast]) {
      link.onFeedback = (msg) {
        if (msg['type'] == 'stats') {
          final src = link == cast ? 'TV' : 'local';
          stats.value =
              '$src ${msg['fps']} i/s · ${msg['renderMs']} ms · ${msg['bg']}';
        }
      };
    }

    local.send({'type': 'config', 'debug': debug});
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
  }

  void setHold(bool v) {
    hold.value = v;
    pilot.setHold(v);
  }

  void flash() => pilot.triggerFlash();
  void drop() => pilot.triggerDrop();
  void scene() => pilot.triggerScene();
  void next() => pilot.triggerNext();

  void setDebug(bool value) {
    debug = value;
    _sendAll({'type': 'config', 'debug': value});
  }

  Future<void> dispose() async {
    _pingTimer?.cancel();
    pilot.stop();
    for (final s in _subs) {
      await s.cancel();
    }
    await _recorder.stop();
    await _recorder.dispose();
    analyzer.dispose();
    cast.dispose();
  }
}
