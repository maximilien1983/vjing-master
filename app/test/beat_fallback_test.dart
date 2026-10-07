import 'package:flutter_test/flutter_test.dart';
import 'package:vjing_master/audio/audio_analyzer.dart';
import 'package:vjing_master/session.dart';

void main() {
  test('sans détection : BPM de secours 120, confiance nulle', () {
    final b = withFallbackBpm(const BeatEstimate(0, 0, 1000, 0));
    expect(b.bpm, kFallbackBpm);
    expect(b.confidence, 0);
    expect(b.t0, 1000);
  });

  test('la grille de secours est ancrée sur l\'horloge epoch', () {
    // Deux messages espacés d'une mesure exacte (2 s à 120 BPM) décrivent la
    // même grille : phase identique, pas de saut côté moteur.
    final a = withFallbackBpm(const BeatEstimate(0, 0, 1000, 0));
    final b = withFallbackBpm(const BeatEstimate(0, 0, 3000, 0));
    expect(b.phase, closeTo(a.phase, 1e-9));
    // À une demi-mesure d'écart, la phase avance de 0,5.
    final c = withFallbackBpm(const BeatEstimate(0, 0, 2000, 0));
    expect(((c.phase - a.phase) % 1 - 0.5).abs(), closeTo(0, 1e-9));
  });

  test('une détection réelle passe sans modification', () {
    const real = BeatEstimate(128, 0.25, 42, 0.9);
    expect(withFallbackBpm(real), same(real));
  });
}
