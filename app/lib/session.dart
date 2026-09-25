import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'audio/audio_analyzer.dart';
import 'cast/cast_link.dart';
import 'engine/engine_link.dart';
import 'engine/webview_link.dart';

/// Session jalon 1 : micro -> analyse -> moteur(s).
/// Le même flux de messages part vers la WebView locale et, si connecté,
/// vers le Chromecast (le moniteur local sert d'aperçu).
class Session {
  final analyzer = AudioAnalyzer();
  final webView = WebViewLink();
  final cast = CastLink();
  final _recorder = AudioRecorder();

  final bpm = ValueNotifier<double>(0);
  final confidence = ValueNotifier<double>(0);
  final levels = ValueNotifier<Levels>(const Levels(0, 0, 0));
  final micOk = ValueNotifier<bool?>(null);
  final castState = ValueNotifier<CastState>(CastState.idle);
  final stats = ValueNotifier<String>('—');
  final latency = ValueNotifier<String>('—');
  bool debug = true;

  final List<StreamSubscription> _subs = [];
  Timer? _pingTimer;

  List<EngineLink> get _links => [
        webView,
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
      _sendAll({
        'type': 'beat',
        'bpm': b.bpm,
        'phase': b.phase,
        't0': b.t0,
        'offsetMs': 0,
        'confidence': b.confidence,
      });
    }));
    _subs.add(cast.states.listen((s) {
      castState.value = s;
      if (s == CastState.connected) {
        // Le receiver démarre muet : on lui pousse l'état debug courant.
        cast.send({'type': 'config', 'debug': debug});
      }
    }));

    for (final link in [webView, cast]) {
      link.onFeedback = (msg) {
        if (msg['type'] == 'stats') {
          final src = link == cast ? 'TV' : 'local';
          stats.value =
              '$src ${msg['fps']} i/s · ${msg['renderMs']} ms · perdu ${msg['droppedFrames']}';
        }
      };
    }

    webView.send({'type': 'config', 'debug': debug});

    // Latence aller-retour mesurée toutes les 2 s sur le lien actif.
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final link =
          cast.state == CastState.connected ? cast : webView;
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
        final stream = await _recorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AudioAnalyzer.sampleRate,
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

  void trigger(String id) => _sendAll({'type': 'trigger', 'id': id});

  void setDebug(bool value) {
    debug = value;
    _sendAll({'type': 'config', 'debug': value});
  }

  Future<void> dispose() async {
    _pingTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _recorder.stop();
    await _recorder.dispose();
    analyzer.dispose();
    cast.dispose();
  }
}
