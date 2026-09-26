import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:vjing_master/autopilot/autopilot.dart';
import 'package:vjing_master/autopilot/presets.dart';
import 'package:vjing_master/sources/clip_catalog.dart';

const _fixture = '''
{
  "version": 1,
  "clips": [
    {
      "id": "steel-01",
      "url": "clips/steel-01.mp4",
      "duree": 12,
      "tags": {"univers": "machines", "epoque": "1946", "luminosite": 0.34, "couleur": "#5a5148"},
      "source": "FedFlix / NARA",
      "licence": "Domaine public",
      "credit": "National Archives and Records Administration"
    },
    {
      "id": "apollo-03",
      "url": "https://exemple.org/apollo-03.mp4",
      "duree": 9,
      "tags": {"univers": "cosmos", "epoque": "1969", "luminosite": 0.72, "couleur": "#aab0c0"}
    }
  ],
  "loops": [
    {
      "id": "3l-spiral",
      "url": "loops/3l-spiral.mp4",
      "duree": 14,
      "styles": ["70s", "psyche"],
      "licence": "Domaine public",
      "credit": "3L"
    }
  ]
}
''';

void main() {
  group('ClipCatalog.parse', () {
    test('résout les URL relatives contre la base, id préfixé cat-', () {
      final data = ClipCatalog.parse(_fixture, 'https://exemple.org/catalog/');
      expect(data.clips, hasLength(2));
      expect(data.clips[0].id, 'cat-steel-01');
      expect(data.clips[0].url,
          'https://exemple.org/catalog/clips/steel-01.mp4');
      expect(data.clips[0].univers, 'machines');
      expect(data.clips[0].luminosite, closeTo(.34, 1e-9));
      // URL absolue : inchangée.
      expect(data.clips[1].url, 'https://exemple.org/apollo-03.mp4');
    });

    test('les boucles portent leurs styles', () {
      final data = ClipCatalog.parse(_fixture, 'base/');
      expect(data.loops, hasLength(1));
      expect(data.loops[0].id, 'loop-3l-spiral');
      expect(data.loops[0].url, 'base/loops/3l-spiral.mp4');
      expect(data.loops[0].styles, containsAll(['70s', 'psyche']));
    });
  });

  group('clipMatchesLight (règle du brief)', () {
    test('clip sombre pioché en lumière basse, écarté en pleine lumière', () {
      final clips = ClipCatalog.parse(_fixture, 'x/').clips;
      final sombre = clips[0]; // luminosité .34
      final clair = clips[1]; // luminosité .72
      expect(clipMatchesLight(sombre, 0.2), isTrue);
      expect(clipMatchesLight(sombre, 1.0), isFalse);
      expect(clipMatchesLight(clair, 1.0), isTrue);
      expect(clipMatchesLight(clair, 0.1), isFalse);
      // Zone médiane : les deux passent (tolérance large).
      expect(clipMatchesLight(sombre, 0.5), isTrue);
      expect(clipMatchesLight(clair, 0.5), isTrue);
    });
  });

  group('Autopilot avec boucles vidéo', () {
    test('au plus une boucle vidéo parmi les motifs superposés', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot = Autopilot(
          style: retrofutur, universe: cosmos, send: msgs.add, rng: Random(5));
      pilot.setLoops(ClipCatalog.parse(_fixture, 'b/').loops);
      pilot.setEnergy(1);
      var sawVideo = false;
      // Drop reconstruit 4 motifs à chaque appel : on échantillonne large.
      for (var i = 0; i < 40; i++) {
        pilot.triggerDrop();
        final scene = msgs.lastWhere((m) => m['type'] == 'scene');
        final overlays =
            (scene['state'] as Map<String, dynamic>)['overlays'] as List;
        expect(overlays, hasLength(4));
        final videos = overlays
            .where((o) => (o as Map<String, dynamic>)['kind'] == 'video')
            .length;
        expect(videos, lessThanOrEqualTo(1), reason: 'itération $i');
        sawVideo |= videos == 1;
        for (final o in overlays.cast<Map<String, dynamic>>()) {
          if (o['kind'] == 'video') {
            expect(o['url'], startsWith('b/loops/'));
            expect(o.containsKey('motif'), isFalse);
          } else {
            expect(retrofutur.motifs, contains(o['motif']));
          }
        }
      }
      expect(sawVideo, isTrue,
          reason: 'les boucles vidéo doivent finir par apparaître');
    });
  });

  test('le catalogue généré (s\'il existe) est valide et cohérent', () {
    final f = File('../catalog/clips.json');
    if (!f.existsSync()) {
      markTestSkipped('catalog/clips.json pas encore généré');
      return;
    }
    // Base vide : les URL relatives restent relatives pour vérifier les
    // fichiers sur disque.
    final data = ClipCatalog.parse(f.readAsStringSync(), '');
    expect(data.clips, isNotEmpty);
    expect(data.loops, isNotEmpty);
    const universes = ['campagne', 'ville', 'cosmos', 'machines', 'nature', 'miroir'];
    for (final c in data.clips) {
      expect(universes, contains(c.univers), reason: c.id);
      expect(c.duree, inInclusiveRange(4, 30), reason: c.id);
      expect(c.luminosite, inInclusiveRange(0, 1), reason: c.id);
      expect(c.licence, isNotEmpty, reason: '${c.id} : licence obligatoire');
      expect(c.credit, isNotEmpty, reason: '${c.id} : crédit obligatoire');
      if (!c.url.startsWith('http')) {
        expect(File('../catalog/${c.url}').existsSync(), isTrue,
            reason: 'fichier manquant : ${c.url}');
      }
    }
    for (final l in data.loops) {
      expect(l.styles, isNotEmpty, reason: '${l.id} : styles obligatoires');
      for (final s in l.styles) {
        expect(styleIds, contains(s), reason: '${l.id} : style inconnu $s');
      }
      expect(l.licence, isNotEmpty, reason: '${l.id} : licence obligatoire');
      expect(l.credit, isNotEmpty, reason: '${l.id} : crédit obligatoire');
      if (!l.url.startsWith('http')) {
        expect(File('../catalog/${l.url}').existsSync(), isTrue,
            reason: 'fichier manquant : ${l.url}');
      }
    }
  });
}
