import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vjing_master/autopilot/autopilot.dart';
import 'package:vjing_master/autopilot/presets.dart';
import 'package:vjing_master/sources/sources_model.dart';
import 'package:vjing_master/ui/widgets/nixie_display.dart';
import 'package:vjing_master/ui/widgets/rotary_selector.dart';
import 'package:vjing_master/ui/widgets/vertical_fader.dart';

void main() {
  group('RotarySelector : aimantation sur les crans', () {
    test('angles exacts', () {
      for (var i = 0; i < rotaryAngles.length; i++) {
        expect(nearestNotch(rotaryAngles[i]), i);
      }
    });

    test('angles intermédiaires arrondis au plus proche', () {
      expect(nearestNotch(-100), 1); // proche de -90
      expect(nearestNotch(-125), 0); // à 25° de -150, 35° de -90
      expect(nearestNotch(160), 5);
      expect(nearestNotch(40), 3);
    });

    test('angles hors [-180, 180] normalisés', () {
      expect(nearestNotch(210), 0); // 210 - 360 = -150
      expect(nearestNotch(-210), 5); // -210 + 360 = 150
      expect(nearestNotch(450), 4); // 450 - 360 = 90
    });
  });

  group('FaderGeometry : course <-> valeur', () {
    test('bornes et milieu (énergie console)', () {
      const g = FaderGeometry.energyConsole;
      expect(g.centerYFor(1), g.tickTop);
      expect(g.centerYFor(0), g.tickBottom);
      expect(g.centerYFor(.5), (g.tickTop + g.tickBottom) / 2);
      expect(g.valueFor(g.tickTop), 1);
      expect(g.valueFor(g.tickBottom), 0);
      expect(g.valueFor(g.tickTop - 50), 1); // au-dessus de la course : borné
      expect(g.valueFor(g.tickBottom + 50), 0);
    });

    test('aller-retour sur toutes les géométries', () {
      const all = [
        FaderGeometry.lightStart,
        FaderGeometry.lightConsole,
        FaderGeometry.energyConsole,
        FaderGeometry.lightDrawer,
        FaderGeometry.energyDrawer,
      ];
      for (final g in all) {
        for (final v in [0.0, .25, .5, .72, 1.0]) {
          expect(g.valueFor(g.centerYFor(v)), closeTo(v, 1e-9));
        }
      }
    });
  });

  group('LED tempo : profil d\'intensité (DESIGN.md §6)', () {
    test('pleine intensité sur le temps, fondu, puis éteinte', () {
      expect(tempoLedIntensity(0), 1);
      expect(tempoLedIntensity(.1), 1);
      expect(tempoLedIntensity(.21), 1);
      expect(tempoLedIntensity(.3), inExclusiveRange(0, 1));
      expect(tempoLedIntensity(.45), 0);
      expect(tempoLedIntensity(.8), 0);
    });

    test('périodique', () {
      expect(tempoLedIntensity(1.1), tempoLedIntensity(.1));
      expect(tempoLedIntensity(2.3), closeTo(tempoLedIntensity(.3), 1e-9));
    });
  });

  group('SourcesModel', () {
    test('bascule locale immédiate, comptage', () {
      final m = SourcesModel();
      expect(m.loadedCount, 3); // caméra + 2 fichiers, comme les maquettes
      final cam = m.sources.firstWhere((s) => s.id == 'camera');
      m.toggle(cam);
      expect(cam.state, SourceState.unloaded);
      expect(m.loadedCount, 2);
      m.toggle(cam);
      expect(cam.state, SourceState.loaded);
      m.dispose();
    });

    test('source distante : chargement progressif puis chargée', () {
      fakeAsync((async) {
        final m = SourcesModel();
        final storm = m.sources.firstWhere((s) => s.id == 'orage-lent');
        m.toggle(storm);
        expect(storm.state, SourceState.loading);
        async.elapse(const Duration(seconds: 1));
        expect(storm.progress, greaterThan(0));
        async.elapse(const Duration(seconds: 5));
        expect(storm.state, SourceState.loaded);
        m.dispose();
      });
    });

    test('toucher pendant le chargement = annuler', () {
      fakeAsync((async) {
        final m = SourcesModel();
        final storm = m.sources.firstWhere((s) => s.id == 'orage-lent');
        m.toggle(storm);
        async.elapse(const Duration(milliseconds: 500));
        m.toggle(storm);
        expect(storm.state, SourceState.unloaded);
        expect(storm.progress, 0);
        async.elapse(const Duration(seconds: 10));
        expect(storm.state, SourceState.unloaded);
        m.dispose();
      });
    });
  });

  group('Autopilot : changement de style et d\'univers', () {
    test('setStyle repousse la scène avec les nouveaux filtres', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot =
          Autopilot(style: retrofutur, universe: cosmos, send: msgs.add);
      pilot.setEnergy(.5); // pousse une première scène
      msgs.clear();
      const autre = StylePreset('essai', ['posterize'], 'cut', 1);
      pilot.setStyle(autre);
      final scene = msgs.lastWhere((m) => m['type'] == 'scene');
      final filters =
          (scene['state'] as Map<String, dynamic>)['filters'] as List<dynamic>;
      expect((filters.single as Map<String, dynamic>)['id'], 'posterize');
    });

    test('setStyle sans changement : aucun message', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot =
          Autopilot(style: retrofutur, universe: cosmos, send: msgs.add);
      pilot.setStyle(retrofutur);
      expect(msgs, isEmpty);
    });

    test('presets inconnus : repli sur Retrofutur × Cosmos (jalon 3)', () {
      expect(stylePresetFor('vhs').id, 'retrofutur');
      expect(universePresetFor('miroir').id, 'cosmos');
      expect(stylePresetFor('retrofutur').id, 'retrofutur');
      expect(universePresetFor('cosmos').id, 'cosmos');
    });

    test('les 6 crans de chaque rotacteur sont déclarés', () {
      expect(styleIds, hasLength(6));
      expect(styleLabels, hasLength(6));
      expect(universeIds, hasLength(6));
      expect(universeLabels, hasLength(6));
      expect(styleIds[3], 'retrofutur'); // cran à 30°, comme la maquette
      expect(universeIds[2], 'cosmos'); // cran à -30°
    });
  });
}
