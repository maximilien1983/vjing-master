import '../audio/audio_analyzer.dart';

/// Horloge de mesure côté app : extrapole la phase entre deux estimations,
/// et compte les mesures absolues pour la quantification de l'autopilote.
/// Miroir du BeatClock du moteur (renderer/src/beatClock.ts).
class BeatClock {
  double _bpm = 0;
  double _phaseAtT0 = 0;
  int _t0 = 0;
  int _measureCount = 0;
  double _lastPhase = 0;

  void update(BeatEstimate e) {
    _bpm = e.bpm;
    _phaseAtT0 = e.phase;
    _t0 = e.t0;
  }

  bool get hasBeat => _bpm > 0;
  double get bpm => _bpm;

  double get measureDurationMs => _bpm > 0 ? 4 * 60000 / _bpm : 2000;

  /// Phase dans la mesure de 4 temps, [0, 1). Sans beat : basée sur 120 BPM
  /// fictif pour que les fondus gardent une durée raisonnable.
  double measurePhase([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final bpm = _bpm > 0 ? _bpm : 120.0;
    final t0 = _bpm > 0 ? _t0 : 0;
    final phase0 = _bpm > 0 ? _phaseAtT0 : 0.0;
    final measures = (now - t0) / 60000 * bpm / 4;
    final p = (phase0 + measures) % 1;
    return p < 0 ? p + 1 : p;
  }

  /// À appeler régulièrement (tick) : vrai si un nouveau temps 1 vient de passer.
  bool tickMeasureBoundary([int? nowMs]) {
    final p = measurePhase(nowMs);
    final crossed = p < _lastPhase;
    _lastPhase = p;
    if (crossed) _measureCount++;
    return crossed;
  }

  int get measureCount => _measureCount;
}
