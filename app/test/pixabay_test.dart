import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:vjing_master/autopilot/autopilot.dart';
import 'package:vjing_master/autopilot/presets.dart';
import 'package:vjing_master/sources/pixabay.dart';

const _fixture = '''
{
  "total": 500, "totalHits": 500,
  "hits": [
    {
      "id": 21118, "duration": 6, "tags": "seoul, traffic, night",
      "videos": {
        "large": {"url": "https://cdn.pixabay.com/video/l.mp4", "width": 1920, "height": 1080},
        "small": {"url": "https://cdn.pixabay.com/video/s.mp4", "width": 1280, "height": 720},
        "tiny": {"url": "https://cdn.pixabay.com/video/t.mp4", "width": 960, "height": 540}
      }
    },
    {
      "id": 99, "duration": 2, "tags": "trop court",
      "videos": {"tiny": {"url": "https://cdn.pixabay.com/video/court.mp4"}}
    },
    {
      "id": 42, "duration": 12, "tags": "sans tiny",
      "videos": {"small": {"url": "https://cdn.pixabay.com/video/small42.mp4"}}
    }
  ]
}
''';

void main() {
  group('PixabayClient.parse', () {
    test('prend la variante tiny, id préfixé px-', () {
      final clips = PixabayClient.parse(_fixture);
      expect(clips.first.id, 'px-21118');
      expect(clips.first.url, 'https://cdn.pixabay.com/video/t.mp4');
      expect(clips.first.duration, 6);
    });

    test('ignore les clips trop courts, repli sur small', () {
      final clips = PixabayClient.parse(_fixture);
      expect(clips.map((c) => c.id), isNot(contains('px-99')));
      expect(clips.last.id, 'px-42');
      expect(clips.last.url, 'https://cdn.pixabay.com/video/small42.mp4');
    });
  });

  group('Autopilot avec clips vidéo', () {
    Autopilot makePilot(List<Map<String, dynamic>> msgs) => Autopilot(
          style: retrofutur,
          universe: cosmos,
          send: msgs.add,
          rng: Random(3),
        );

    test('la scène passe en kind video avec URL quand un clip est tiré', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot = makePilot(msgs);
      pilot.setClips(const [
        PixabayClip('px-1', 'https://cdn/x.mp4', 10, ''),
      ]);
      // Le pool contient 4 shaders + 1 clip : on force le tirage jusqu'au clip.
      var found = false;
      pilot.setEnergy(.5);
      for (var i = 0; i < 20 && !found; i++) {
        pilot.triggerNext();
        final bg = (msgs.lastWhere((m) => m['type'] == 'scene')['state']
            as Map<String, dynamic>)['background'] as Map<String, dynamic>;
        if (bg['kind'] == 'video') {
          expect(bg['id'], 'px-1');
          expect(bg['url'], 'https://cdn/x.mp4');
          found = true;
        }
      }
      expect(found, isTrue, reason: 'le clip doit finir par être pioché');
    });

    test('banOnError remplace le fond fautif et le bannit', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot = makePilot(msgs);
      pilot.setClips(const [PixabayClip('px-1', 'https://cdn/x.mp4', 10, '')]);
      pilot.setEnergy(.5);
      // Force le clip comme fond courant.
      while ((msgs.lastWhere((m) => m['type'] == 'scene')['state']
              as Map<String, dynamic>)['background']['kind'] !=
          'video') {
        pilot.triggerNext();
      }
      pilot.banOnError('px-1');
      expect(pilot.banned, contains('px-1'));
      final bg = (msgs.lastWhere((m) => m['type'] == 'scene')['state']
          as Map<String, dynamic>)['background'] as Map<String, dynamic>;
      expect(bg['id'], isNot('px-1'));
    });

    test('changement d\'univers : le pool de clips est vidé', () {
      final msgs = <Map<String, dynamic>>[];
      final pilot = makePilot(msgs);
      pilot.setClips(const [PixabayClip('px-1', 'https://cdn/x.mp4', 10, '')]);
      pilot.setUniverse(const UniversePreset('essai', ['cosmos-stars']));
      pilot.setEnergy(.5);
      for (var i = 0; i < 10; i++) {
        pilot.triggerNext();
        final bg = (msgs.lastWhere((m) => m['type'] == 'scene')['state']
            as Map<String, dynamic>)['background'] as Map<String, dynamic>;
        expect(bg['kind'], 'shader');
      }
    });
  });

  test('les univers du catalogue portent leurs requêtes Pixabay', () {
    PresetCatalog.reset();
    // Le fichier de référence est lu par presets_test ; ici on vérifie juste
    // le parsing de la clé "pixabay".
    PresetCatalog.apply('''
{
  "styles": {"retrofutur": {"label": "R", "filters": ["bloom"],
    "transition": {"kind": "crossfade", "beats": 2}, "motifs": ["grid"]}},
  "universes": {"ville": {"label": "Ville", "backgrounds": ["ville-skyline"],
    "pixabay": ["city night traffic"]}}
}
''');
    expect(universePresetFor('ville').queries, ['city night traffic']);
    PresetCatalog.reset();
  });
}
