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

  group('overlayTarget / filterIntensity', () {
    test('0 boucle et 20 % à énergie 0, 4 boucles et 100 % à énergie 100', () {
      expect(overlayTarget(0, StructureState.steady), 0);
      expect(overlayTarget(1, StructureState.steady), 4);
      expect(filterIntensity(0, StructureState.steady), closeTo(0.2, 1e-9));
      expect(filterIntensity(1, StructureState.steady), closeTo(1.0, 1e-9));
    });
    test('drop : filtres au maximum, plafond de 4 boucles', () {
      expect(filterIntensity(0.3, StructureState.drop), 1.0);
      expect(overlayTarget(1, StructureState.drop), 4);
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
    test('Suivant bannit le fond courant pour la session', () {
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
      pilot.triggerNext();
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
        pilot.triggerNext();
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
      expect(state['filters'], isNotEmpty);
      for (final f in state['filters'] as List) {
        expect(retrofutur.filterIds, contains(f['id']));
        expect(f['intensity'], inInclusiveRange(0.2, 1.0));
      }
      expect(state['transition']['kind'], 'crossfade');
      pilot.stop();
    });
  });
}
