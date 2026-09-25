import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vjing_master/audio/audio_analyzer.dart';

/// Génère un signal de kicks synthétiques au BPM donné : burst de sinus
/// basse fréquence (60 Hz) avec enveloppe décroissante, toutes les périodes.
Uint8List synthKicks({
  required double bpm,
  required double seconds,
  int sampleRate = 44100,
}) {
  final total = (seconds * sampleRate).round();
  final samples = Int16List(total);
  final beatPeriod = 60.0 / bpm;
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final sinceBeat = t % beatPeriod;
    double v = 0;
    if (sinceBeat < 0.12) {
      final env = math.exp(-sinceBeat * 40);
      v = math.sin(2 * math.pi * 60 * sinceBeat) * env * 0.9;
    }
    samples[i] = (v * 32767).round();
  }
  return samples.buffer.asUint8List();
}

void main() {
  test('détecte un tempo de 124 BPM sur des kicks synthétiques', () async {
    final analyzer = AudioAnalyzer();
    final estimates = <BeatEstimate>[];
    final sub = analyzer.beats.listen(estimates.add);

    // 12 s de signal, injecté par blocs comme le ferait le micro.
    final pcm = synthKicks(bpm: 124, seconds: 12);
    const block = 4096;
    for (var i = 0; i < pcm.length; i += block) {
      analyzer.addPcm16(Uint8List.sublistView(
          pcm, i, math.min(i + block, pcm.length)));
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    analyzer.dispose();

    expect(estimates, isNotEmpty, reason: 'aucune estimation émise');
    final last = estimates.last;
    expect(last.bpm, closeTo(124, 3),
        reason: 'BPM détecté : ${last.bpm} (confiance ${last.confidence})');
  });

  test('le BPM reste stable sur un tempo constant (pas d\'oscillation)', () async {
    final analyzer = AudioAnalyzer();
    final estimates = <BeatEstimate>[];
    final sub = analyzer.beats.listen(estimates.add);

    final pcm = synthKicks(bpm: 124, seconds: 30);
    const block = 4096;
    for (var i = 0; i < pcm.length; i += block) {
      analyzer.addPcm16(Uint8List.sublistView(
          pcm, i, math.min(i + block, pcm.length)));
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    analyzer.dispose();

    // Une fois verrouillé (après ~12 s), l'estimation ne doit plus osciller :
    // écart max-min sous 1,5 BPM sur toute la suite de la session.
    final startMs = estimates.first.t0;
    final locked = estimates
        .where((e) => e.bpm > 0 && e.t0 - startMs > 12000)
        .map((e) => e.bpm)
        .toList();
    expect(locked, isNotEmpty);
    final spread =
        locked.reduce(math.max) - locked.reduce(math.min);
    expect(spread, lessThan(1.5),
        reason: 'BPM oscillant : ${locked.map((b) => b.toStringAsFixed(1))}');
  });

  test('la phase colle aux kicks (pulsation calée sur le temps)', () async {
    final analyzer = AudioAnalyzer();
    final estimates = <BeatEstimate>[];
    final sub = analyzer.beats.listen(estimates.add);

    const bpm = 124.0;
    final pcm = synthKicks(bpm: bpm, seconds: 15);
    // Capturé juste avant le premier bloc : l'horloge du flux démarre là.
    final startMs = DateTime.now().millisecondsSinceEpoch;
    const block = 4096;
    for (var i = 0; i < pcm.length; i += block) {
      analyzer.addPcm16(Uint8List.sublistView(
          pcm, i, math.min(i + block, pcm.length)));
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    analyzer.dispose();

    // Les kicks tombent à phase de temps 0 (t = k * 60/bpm depuis le début du
    // flux). On vérifie les dernières estimations : la phase de temps estimée
    // doit coller à la vraie, à ~0,2 temps près (latence d'attaque comprise).
    final beatDurMs = 60000 / bpm;
    final recent = estimates.where((e) => e.bpm > 0).toList().reversed.take(3);
    expect(recent, isNotEmpty);
    for (final e in recent) {
      final estBeatPhase = (e.phase * 4) % 1;
      final trueBeatPhase = ((e.t0 - startMs) / beatDurMs) % 1;
      var diff = (estBeatPhase - trueBeatPhase).abs();
      if (diff > 0.5) diff = 1 - diff;
      expect(diff, lessThan(0.2),
          reason: 'phase estimée $estBeatPhase vs réelle $trueBeatPhase '
              '(bpm ${e.bpm})');
    }
  });

  test('bpm = 0 sur du silence', () async {
    final analyzer = AudioAnalyzer();
    final estimates = <BeatEstimate>[];
    final sub = analyzer.beats.listen(estimates.add);

    final silence = Uint8List(10 * 44100 * 2);
    const block = 4096;
    for (var i = 0; i < silence.length; i += block) {
      analyzer.addPcm16(Uint8List.sublistView(
          silence, i, math.min(i + block, silence.length)));
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    analyzer.dispose();

    expect(estimates.where((e) => e.bpm > 0), isEmpty,
        reason: 'du tempo a été détecté dans le silence');
  });
}
