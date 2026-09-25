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
