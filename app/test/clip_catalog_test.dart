import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  ]
}
''';

void main() {
  group('ClipCatalog.parse', () {
    test('résout les URL relatives contre la base, id préfixé cat-', () {
      final clips =
          ClipCatalog.parse(_fixture, 'https://exemple.org/catalog/');
      expect(clips, hasLength(2));
      expect(clips[0].id, 'cat-steel-01');
      expect(clips[0].url, 'https://exemple.org/catalog/clips/steel-01.mp4');
      expect(clips[0].univers, 'machines');
      expect(clips[0].luminosite, closeTo(.34, 1e-9));
      // URL absolue : inchangée.
      expect(clips[1].url, 'https://exemple.org/apollo-03.mp4');
    });
  });

  group('clipMatchesLight (règle du brief)', () {
    test('clip sombre pioché en lumière basse, écarté en pleine lumière', () {
      final clips = ClipCatalog.parse(_fixture, 'x/');
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

  test('le catalogue généré (s\'il existe) est valide et cohérent', () {
    final f = File('../catalog/clips.json');
    if (!f.existsSync()) {
      markTestSkipped('catalog/clips.json pas encore généré');
      return;
    }
    // Base vide : les URL relatives restent relatives pour vérifier les
    // fichiers sur disque.
    final clips = ClipCatalog.parse(f.readAsStringSync(), '');
    expect(clips, isNotEmpty);
    const universes = ['campagne', 'ville', 'cosmos', 'machines', 'nature', 'miroir'];
    for (final c in clips) {
      expect(universes, contains(c.univers), reason: c.id);
      expect(c.duree, inInclusiveRange(4, 30), reason: c.id);
      expect(c.luminosite, inInclusiveRange(0, 1), reason: c.id);
      expect(c.licence, isNotEmpty, reason: '${c.id} : licence obligatoire');
      expect(c.credit, isNotEmpty, reason: '${c.id} : crédit obligatoire');
      // Les fichiers découpés doivent exister à côté du catalogue.
      if (!c.url.startsWith('http')) {
        expect(File('../catalog/${c.url}').existsSync(), isTrue,
            reason: 'fichier manquant : ${c.url}');
      }
    }
  });
}
