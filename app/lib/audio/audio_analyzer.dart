import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// Estimation de tempo produite par l'analyseur.
class BeatEstimate {
  final double bpm; // 0 = pas de beat détecté
  final double phase; // position dans la mesure de 4 temps, [0, 1)
  final int t0; // epoch ms où `phase` était valable
  final double confidence;

  const BeatEstimate(this.bpm, this.phase, this.t0, this.confidence);
}

/// Niveaux lissés par bande, [0, 1].
class Levels {
  final double low, mid, high;
  const Levels(this.low, this.mid, this.high);
}

/// Structure musicale détectée par variation d'énergie sur 8 à 16 mesures.
enum StructureState {
  calm, // énergie durablement basse : dérive lente
  steady, // régime de croisière
  rise, // montée : l'autopilote resserre les changements
  drop, // pic soudain après une montée : lâcher tout
}

/// Analyse un flux PCM 16 bits mono : bandes lissées, attaques par flux
/// spectral (priorité aux basses), BPM par autocorrélation, phase de mesure.
/// Tout est basé sur l'horloge des échantillons, pas sur des timers.
class AudioAnalyzer {
  /// 44,1 kHz sur mobile ; les navigateurs travaillent presque tous à 48 kHz.
  final int sampleRate;
  static const int fftSize = 2048;
  static const int hopSize = 1024; // ~43 analyses/s à 44,1 kHz

  // Fenêtre d'autocorrélation : ~8 s d'enveloppe d'attaques.
  static const int onsetWindow = 344;
  static const double minBpm = 60, maxBpm = 180;

  AudioAnalyzer({this.sampleRate = 44100});

  double get hopsPerSecond => sampleRate / hopSize;

  final _fft = FFT(fftSize);
  late final Float64List _hann = Float64List.fromList(List.generate(
      fftSize, (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / fftSize)));

  final List<double> _pending = [];
  int _totalHops = 0;
  int? _streamStartMs; // epoch ms du premier échantillon reçu

  Float64List? _prevMags;
  final Float64List _onsets = Float64List(onsetWindow);
  int _onsetWrite = 0;

  // AGC par bande : maximum glissant à décroissance lente.
  final _bandMax = [1e-6, 1e-6, 1e-6];
  final _bandSmooth = [0.0, 0.0, 0.0];

  double _bpm = 0;
  double _confidence = 0;
  int _anchorMs = 0; // epoch ms d'un temps (ancre de phase)
  int _lastBeatSentMs = 0;
  double _lastSentBpm = -1;
  int _lastLevelsSentMs = 0;
  int _lastBpmComputeHop = 0;

  // Structure : énergie par hop sur ~20 s, comparaison court terme / long terme.
  static const int _energyWindow = 860; // ~20 s à 43 hops/s
  final Float64List _energyHist = Float64List(_energyWindow);
  int _energyWrite = 0;
  int _energyCount = 0;
  double _energyMax = 1e-6;
  StructureState _structure = StructureState.steady;
  int _dropHoldUntilHop = 0;
  double _prevShort = 0;
  double _shortSlope = 0;

  final _levelsCtrl = StreamController<Levels>.broadcast();
  final _beatCtrl = StreamController<BeatEstimate>.broadcast();
  final _structureCtrl = StreamController<StructureState>.broadcast();

  Stream<Levels> get levels => _levelsCtrl.stream;
  Stream<BeatEstimate> get beats => _beatCtrl.stream;
  Stream<StructureState> get structures => _structureCtrl.stream;
  StructureState get currentStructure => _structure;

  Levels get currentLevels =>
      Levels(_bandSmooth[0], _bandSmooth[1], _bandSmooth[2]);
  double get currentBpm => _bpm;
  double get currentConfidence => _confidence;

  /// Bytes PCM 16 bits little-endian mono, tels que fournis par `record`.
  void addPcm16(Uint8List bytes) {
    _streamStartMs ??= DateTime.now().millisecondsSinceEpoch;
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _pending.add(data.getInt16(i, Endian.little) / 32768.0);
    }
    while (_pending.length >= fftSize) {
      _analyzeHop();
      _pending.removeRange(0, hopSize);
      _totalHops++;
    }
  }

  /// Epoch ms correspondant au hop d'index donné (horloge des échantillons).
  int _hopMs(int hop) =>
      (_streamStartMs ?? 0) + (hop * hopSize * 1000 ~/ sampleRate);

  void _analyzeHop() {
    final chunk = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      chunk[i] = _pending[i] * _hann[i];
    }
    final mags = _fft.realFft(chunk).discardConjugates().magnitudes();

    // Bandes : basses 20-150 Hz, médiums 150-2000, aigus 2000-16000.
    final binHz = sampleRate / fftSize; // ~21.5 Hz à 44,1 kHz
    final low = _bandMean(mags, 20 ~/ binHz + 1, 150 ~/ binHz + 1);
    final mid = _bandMean(mags, 150 ~/ binHz + 1, 2000 ~/ binHz + 1);
    final high = _bandMean(mags, 2000 ~/ binHz + 1, 16000 ~/ binHz + 1);
    final raw = [low, mid, high];
    for (var b = 0; b < 3; b++) {
      _bandMax[b] = math.max(_bandMax[b] * 0.9995, math.max(raw[b], 1e-6));
      final norm = (raw[b] / _bandMax[b]).clamp(0.0, 1.0);
      // Attaque rapide, relâchement plus lent.
      final k = norm > _bandSmooth[b] ? 0.6 : 0.25;
      _bandSmooth[b] += (norm - _bandSmooth[b]) * k;
    }

    // Flux spectral, pondéré vers les basses pour résister aux voix.
    var flux = 0.0;
    if (_prevMags != null) {
      final lowEnd = 150 ~/ binHz + 1;
      final midEnd = 2000 ~/ binHz + 1;
      for (var i = 1; i < mags.length; i++) {
        final d = mags[i] - _prevMags![i];
        if (d > 0) flux += i < lowEnd ? d * 3.0 : (i < midEnd ? d * 0.5 : d * 0.2);
      }
    }
    _prevMags = Float64List.fromList(mags);
    _onsets[_onsetWrite] = flux;
    _onsetWrite = (_onsetWrite + 1) % onsetWindow;

    // Énergie brute pondérée basses pour la structure.
    _energyMax = math.max(_energyMax * 0.9999, 1e-6);
    final hopEnergy = raw[0] * 2 + raw[1] + raw[2] * 0.5;
    _energyMax = math.max(_energyMax, hopEnergy);
    _energyHist[_energyWrite] = hopEnergy / _energyMax;
    _energyWrite = (_energyWrite + 1) % _energyWindow;
    if (_energyCount < _energyWindow) _energyCount++;
    if (_totalHops % 43 == 0) _updateStructure();

    final nowMs = _hopMs(_totalHops);
    if (nowMs - _lastLevelsSentMs >= 80) {
      _lastLevelsSentMs = nowMs;
      _levelsCtrl.add(currentLevels);
    }
    // BPM recalculé 2 fois par seconde.
    if (_totalHops - _lastBpmComputeHop >= hopsPerSecond ~/ 2 &&
        _totalHops >= onsetWindow) {
      _lastBpmComputeHop = _totalHops;
      _updateTempo(nowMs);
    }
    _maybeEmitBeat(nowMs);
  }

  double _bandMean(Float64List mags, int from, int to) {
    var sum = 0.0;
    final end = math.min(to, mags.length);
    for (var i = from; i < end; i++) {
      sum += mags[i];
    }
    return sum / math.max(1, end - from);
  }

  /// Enveloppe d'attaques dans l'ordre chronologique.
  Float64List _chronoOnsets() {
    final out = Float64List(onsetWindow);
    for (var i = 0; i < onsetWindow; i++) {
      out[i] = _onsets[(_onsetWrite + i) % onsetWindow];
    }
    // Retire la moyenne pour une autocorrélation propre.
    final mean = out.reduce((a, b) => a + b) / onsetWindow;
    for (var i = 0; i < onsetWindow; i++) {
      out[i] -= mean;
    }
    return out;
  }

  void _updateTempo(int nowMs) {
    final env = _chronoOnsets();
    var energy = 0.0;
    for (final v in env) {
      energy += v * v;
    }
    if (energy < 1e-12) {
      _setNoBeat();
      return;
    }

    final minLag = (hopsPerSecond * 60 / maxBpm).floor(); // ~14
    final maxLag = (hopsPerSecond * 60 / minBpm).ceil(); // ~43
    var bestLag = 0;
    var bestVal = 0.0;
    var sumVal = 0.0;
    var count = 0;
    final vals = Float64List(maxLag + 2);
    for (var lag = minLag; lag <= maxLag; lag++) {
      var acc = 0.0;
      for (var i = lag; i < onsetWindow; i++) {
        acc += env[i] * env[i - lag];
      }
      acc /= (onsetWindow - lag);
      vals[lag] = acc;
      sumVal += acc;
      count++;
      if (acc > bestVal) {
        bestVal = acc;
        bestLag = lag;
      }
    }
    final meanVal = sumVal / count;
    if (bestLag == 0 || bestVal <= 0 || meanVal <= 0) {
      _setNoBeat();
      return;
    }
    final confidence = ((bestVal / (meanVal.abs() + 1e-12)) / 4).clamp(0.0, 1.0);
    if (confidence < 0.25) {
      _setNoBeat();
      return;
    }

    // Interpolation parabolique autour du pic pour affiner le lag.
    var lag = bestLag.toDouble();
    if (bestLag > minLag && bestLag < maxLag) {
      final a = vals[bestLag - 1], b = vals[bestLag], c = vals[bestLag + 1];
      final denom = a - 2 * b + c;
      if (denom.abs() > 1e-12) lag += 0.5 * (a - c) / denom;
    }
    var bpm = 60.0 * hopsPerSecond / lag;
    // Préférer la plage 85-170 : corrige les erreurs d'octave.
    while (bpm < 85 && bpm * 2 <= maxBpm) {
      bpm *= 2;
    }
    while (bpm > 170 && bpm / 2 >= minBpm) {
      bpm /= 2;
    }

    // Lissage : on ne saute que si l'estimation s'écarte durablement.
    _bpm = _bpm > 0 && (bpm - _bpm).abs() / _bpm < 0.08
        ? _bpm + (bpm - _bpm) * 0.2
        : bpm;
    _confidence = confidence;
    _updatePhaseAnchor(nowMs);
  }

  void _setNoBeat() {
    _bpm = 0;
    _confidence = 0;
  }

  /// Moyenne des `n` derniers hops d'énergie, en remontant depuis l'écriture.
  double _energyAvg(int n, [int skip = 0]) {
    n = math.min(n, _energyCount - skip);
    if (n <= 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final idx = (_energyWrite - 1 - skip - i + _energyWindow * 2) % _energyWindow;
      sum += _energyHist[idx];
    }
    return sum / n;
  }

  /// Appelée ~1 fois par seconde. Fenêtres exprimées en hops (~43/s) : le
  /// court terme ~2 s, le long terme ~15 s (8 à 16 mesures selon le tempo).
  void _updateStructure() {
    if (_energyCount < 430) return; // moins de 10 s d'historique : trop tôt
    final short = _energyAvg(86);
    final long = _energyAvg(645);
    _shortSlope = short - _prevShort;
    _prevShort = short;

    StructureState next;
    if (_totalHops < _dropHoldUntilHop) {
      next = StructureState.drop;
    } else if (long > 1e-6 && short > long * 1.55 && _shortSlope > 0.04) {
      // Pic soudain nettement au-dessus du régime : drop, tenu ~4 mesures.
      next = StructureState.drop;
      final beatDurHops = _bpm > 0 ? hopsPerSecond * 60 / _bpm : hopsPerSecond * 0.5;
      _dropHoldUntilHop = _totalHops + (beatDurHops * 16).round();
    } else if (short > long * 1.12 && _shortSlope > 0.015) {
      next = StructureState.rise;
    } else if (short < long * 0.55) {
      next = StructureState.calm;
    } else {
      next = StructureState.steady;
    }
    if (next != _structure) {
      _structure = next;
      _structureCtrl.add(next);
    }
  }

  /// Cale l'ancre de phase : offset du peigne qui maximise l'alignement
  /// des attaques sur la période détectée.
  void _updatePhaseAnchor(int nowMs) {
    final periodHops = 60.0 * hopsPerSecond / _bpm;
    final env = _chronoOnsets();
    final steps = periodHops.floor();
    var bestOffset = 0;
    var bestScore = -double.infinity;
    for (var offset = 0; offset < steps; offset++) {
      var score = 0.0;
      for (var k = 0; ; k++) {
        final idx = onsetWindow - 1 - offset - (k * periodHops).round();
        if (idx < 0) break;
        score += env[idx];
      }
      if (score > bestScore) {
        bestScore = score;
        bestOffset = offset;
      }
    }
    // Le dernier temps est tombé il y a `bestOffset` hops.
    final beatMs = nowMs - (bestOffset * 1000 / hopsPerSecond).round();
    final beatDurMs = 60000.0 / _bpm;
    if (_anchorMs == 0) {
      _anchorMs = beatMs;
    } else {
      // Corrige l'ancre en douceur : on la déplace d'un nombre entier de
      // temps + une fraction de l'erreur, pour éviter les sauts de phase.
      final drift = (beatMs - _anchorMs) % beatDurMs;
      final err = drift > beatDurMs / 2 ? drift - beatDurMs : drift;
      _anchorMs += (err * 0.3).round();
    }
  }

  void _maybeEmitBeat(int nowMs) {
    final changed = (_bpm - _lastSentBpm).abs() > 0.5;
    final due = nowMs - _lastBeatSentMs >= 2000;
    if (!changed && !due) return;
    _lastSentBpm = _bpm;
    _lastBeatSentMs = nowMs;
    if (_bpm <= 0) {
      _beatCtrl.add(BeatEstimate(0, 0, nowMs, 0));
      return;
    }
    final beatDurMs = 60000.0 / _bpm;
    final beatsSinceAnchor = (nowMs - _anchorMs) / beatDurMs;
    // Mesure de 4 temps ; le temps 1 est arbitraire au jalon 1.
    final phase = (beatsSinceAnchor / 4) % 1;
    _beatCtrl.add(
        BeatEstimate(_bpm, phase < 0 ? phase + 1 : phase, nowMs, _confidence));
  }

  void dispose() {
    _levelsCtrl.close();
    _beatCtrl.close();
    _structureCtrl.close();
  }
}
