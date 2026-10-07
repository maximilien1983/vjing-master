import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vjing_master/audio/audio_analyzer.dart';
import 'package:vjing_master/autopilot/autopilot.dart';
import 'package:vjing_master/autopilot/presets.dart';

void main() {
  group('changeIntervalMeasures', () {
    test('32 mesures à énergie 0, 4 à énergie 100 (brief)', () {
      expect(changeIntervalMeasures(0, StructureState.steady), 32);
      expect(changeIntervalMeasures(1, StructureState.steady), 4);
    });
    test('montée : intervalle divisé par 2, calme : rallongé', () {
      expect(changeIntervalMeasures(0.5, StructureState.rise),
          changeIntervalMeasures(0.5, StructureState.steady) / 2);
      expect(changeIntervalMeasures(0.5, StructureState.calm),
          greaterThan(changeIntervalMeasures(0.5, StructureState.steady)));
    });
    test('jamais sous 2 mesures', () {
      expect(changeIntervalMeasures(1, StructureState.rise), greaterThanOrEqualTo(2));
    });
  });

  group('séquenceur d\'effets vidéo', () {
    Autopilot makePilot(List<Map<String, dynamic>> msgs, {int seed = 3}) =>
        Autopilot(
            style: retrofutur,
            universe: cosmos,
            send: msgs.add,
            rng: Random(seed));

    test('1 à 3 effets du bassin, intensités et pulsations bornées', () {
      final pilot = makePilot([]);
      for (var i = 0; i < 60; i++) {
        pilot.debugMutateFx(allowPause: false);
        expect(pilot.activeFx, isNotEmpty);
        expect(pilot.activeFx.length, inInclusiveRange(1, 3));
        for (final f in pilot.activeFx) {
          expect(retrofutur.filterIds, contains(f.id));
          expect(f.intensity, inInclusiveRange(0.1, 1.0));
          expect(f.pulse, inInclusiveRange(0.2, 1.0));
        }
      }
    });

    test('les effets s\'enchaînent : le tirage varie', () {
      final pilot = makePilot([]);
      final sets = <String>{};
      for (var i = 0; i < 30; i++) {
        pilot.debugMutateFx(allowPause: false);
        sets.add((pilot.activeFx.map((f) => f.id).toList()..sort()).join('+'));
      }
      expect(sets.length, greaterThan(1),
          reason: 'le même jeu d\'effets ne doit pas tourner en boucle');
    });

    test('parfois une pause : plus aucun effet', () {
      final pilot = makePilot([]);
      var sawPause = false;
      for (var i = 0; i < 200 && !sawPause; i++) {
        pilot.debugMutateFx();
        sawPause = pilot.activeFx.isEmpty;
      }
      expect(sawPause, isTrue, reason: 'les pauses font partie du brief');
    });

    test('drop : tout au maximum', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot = makePilot(msgs);
      pilot.triggerDrop();
      expect(pilot.activeFx, isNotEmpty);
      for (final f in pilot.activeFx) {
        expect(f.intensity, 1.0);
      }
    });

    test('le gain de l\'univers rend les effets plus ou moins marqués', () {
      const doux = UniversePreset('doux', ['cosmos-sun'], [], 0.5);
      const marque = UniversePreset('marque', ['cosmos-sun'], [], 1.0);
      double maxIntensity(UniversePreset u) {
        final pilot = Autopilot(
            style: retrofutur, universe: u, send: (_) {}, rng: Random(9));
        pilot.setEnergy(1);
        var best = 0.0;
        for (var i = 0; i < 40; i++) {
          pilot.debugMutateFx(allowPause: false);
          for (final f in pilot.activeFx) {
            if (f.intensity > best) best = f.intensity;
          }
        }
        return best;
      }

      expect(maxIntensity(doux), lessThan(maxIntensity(marque)));
    });

    test('les filtres signatures de l\'univers se mêlent au bassin', () {
      const miroir =
          UniversePreset('miroir', ['miroir-kaleido'], [], 1.3, ['kaleido']);
      final pilot = Autopilot(
          style: retrofutur, universe: miroir, send: (_) {}, rng: Random(2));
      var sawSignature = false;
      for (var i = 0; i < 80 && !sawSignature; i++) {
        pilot.debugMutateFx(allowPause: false);
        sawSignature = pilot.activeFx.any((f) => f.id == 'kaleido');
      }
      expect(sawSignature, isTrue);
    });
  });

  group('selectBackground', () {
    final all = ['a', 'b', 'c', 'd'];
    test('évite l\'historique récent', () {
      final rng = Random(42);
      for (var i = 0; i < 50; i++) {
        final pick = selectBackground(rng, all, ['a', 'b', 'c'], {});
        expect(pick, 'd');
      }
    });
    test('ignore les fonds bannis', () {
      final rng = Random(42);
      for (var i = 0; i < 50; i++) {
        final pick = selectBackground(rng, all, [], {'a', 'b'});
        expect(['c', 'd'], contains(pick));
      }
    });
    test('historique saturé : retombe sur le pool complet sans planter', () {
      final rng = Random(42);
      final pick = selectBackground(rng, all, ['a', 'b', 'c', 'd', 'a', 'b'], {});
      expect(all, contains(pick));
    });
    test('tout banni : on pioche quand même (jamais d\'écran figé)', () {
      final rng = Random(42);
      final pick = selectBackground(rng, all, [], {'a', 'b', 'c', 'd'});
      expect(all, contains(pick));
    });
  });

  group('Autopilot', () {
    test('banOnError bannit le fond courant et le remplace', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot = Autopilot(
        style: retrofutur,
        universe: cosmos,
        send: msgs.add,
        rng: Random(7),
      );
      pilot.start();
      final first = (msgs.last['state']
          as Map<String, dynamic>)['background']['id'] as String;
      pilot.banOnError(first);
      expect(pilot.banned, contains(first));
      final second = (msgs.last['state']
          as Map<String, dynamic>)['background']['id'] as String;
      expect(second, isNot(first));
      pilot.stop();
    });

    test('l\'historique ne dépasse jamais 10 fonds', () {
      final pilot = Autopilot(
        style: retrofutur,
        universe: cosmos,
        send: (_) {},
        rng: Random(7),
      );
      pilot.start();
      for (var i = 0; i < 30; i++) {
        pilot.triggerDrop();
      }
      expect(pilot.history.length, lessThanOrEqualTo(10));
      pilot.stop();
    });

    test('la scène envoyée est conforme au protocole', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot = Autopilot(
        style: retrofutur,
        universe: cosmos,
        send: msgs.add,
        rng: Random(1),
      );
      pilot.start();
      final initial = msgs.firstWhere((m) => m['type'] == 'scene');
      expect((initial['state'] as Map<String, dynamic>)['transition']['kind'],
          'cut', reason: 'la scène de démarrage arrive sans fondu');
      pilot.setEnergy(0.7); // pousse une scène courante, en fondu cette fois
      final scene = msgs.lastWhere((m) => m['type'] == 'scene');
      final state = scene['state'] as Map<String, dynamic>;
      expect(state['background']['kind'], 'shader');
      expect(cosmos.backgrounds, contains(state['background']['id']));
      // Plus de motifs superposés : les effets vidéo séquencés les remplacent.
      expect(state['overlays'], isEmpty);
      expect(state['filters'], isNotEmpty,
          reason: 'la scène de départ arrive toujours avec des effets');
      for (final f in state['filters'] as List) {
        expect(retrofutur.filterIds, contains(f['id']));
        expect(f['intensity'], inInclusiveRange(0.1, 1.0));
        expect(f['pulse'], inInclusiveRange(0.0, 1.0));
      }
      expect(state['transition']['kind'], 'crossfade');
      pilot.stop();
    });
  });
}
