import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vjing_master/autopilot/autopilot.dart';
import 'package:vjing_master/autopilot/presets.dart';

void main() {
  Map<String, dynamic> lastScene(List<Map<String, dynamic>> msgs) =>
      msgs.lastWhere((m) => m['type'] == 'scene');

  Autopilot makePilot(List<Map<String, dynamic>> msgs) => Autopilot(
      style: retrofutur, universe: cosmos, send: msgs.add, rng: Random(1));

  test('bouton caméra : affichage immédiat, fond maintenu, puis masquage', () {
    final msgs = <Map<String, dynamic>>[];
    final pilot = makePilot(msgs);

    pilot.setCameraPinned(true);
    expect(lastScene(msgs)['state']['background'],
        {'kind': 'camera', 'id': Autopilot.cameraBgId});

    // Tant que la caméra est affichée, un changement de fond (ici forcé par
    // un drop) ne la remplace pas.
    pilot.triggerDrop();
    expect(lastScene(msgs)['state']['background']['kind'], 'camera');

    // Masquage : la rotation reprend sur un fond du bassin.
    pilot.setCameraPinned(false);
    expect(lastScene(msgs)['state']['background']['kind'], 'shader');
  });

  test('caméra refusée (bgerror) : remplacée et maintien libéré', () {
    final msgs = <Map<String, dynamic>>[];
    final pilot = makePilot(msgs);

    pilot.setCameraPinned(true);
    pilot.banOnError(Autopilot.cameraBgId);
    expect(lastScene(msgs)['state']['background']['kind'], 'shader');

    // Bannie : la rotation ne la repiochera plus, mais le bouton permet de
    // retenter (dé-bannie au passage).
    pilot.setCameraPinned(true);
    expect(lastScene(msgs)['state']['background']['kind'], 'camera');
  });

  test('source caméra déchargée pendant l\'affichage : fond remplacé', () {
    final msgs = <Map<String, dynamic>>[];
    final pilot = makePilot(msgs);

    pilot.setCamera(true);
    pilot.setCameraPinned(true);
    pilot.setCamera(false);
    expect(lastScene(msgs)['state']['background']['kind'], 'shader');
  });
}
