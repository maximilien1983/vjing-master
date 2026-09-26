import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vjing_master/autopilot/presets.dart';

/// Les tests tournent depuis app/ : le monorepo est un cran au-dessus.
final catalogFile = File('../catalog/presets.json');
final assetFile = File('assets/catalog/presets.json');
final shadersFile = File('../renderer/src/shaders.ts');
final engineFile = File('../renderer/src/engine.ts');

void main() {
  tearDown(PresetCatalog.reset);

  test('la copie embarquée est identique au catalogue de référence', () {
    expect(assetFile.readAsStringSync(), catalogFile.readAsStringSync(),
        reason: 'Recopier /catalog/presets.json vers app/assets/catalog/.');
  });

  test('le catalogue déclare les 6 styles et 6 univers des rotacteurs', () {
    PresetCatalog.apply(catalogFile.readAsStringSync());
    expect(PresetCatalog.styles.keys, containsAll(styleIds));
    expect(PresetCatalog.universes.keys, containsAll(universeIds));
    for (final s in PresetCatalog.styles.values) {
      expect(s.filterIds, isNotEmpty, reason: 'style ${s.id} sans filtre');
      expect(s.motifs, isNotEmpty, reason: 'style ${s.id} sans motif');
      expect(['crossfade', 'cut'], contains(s.transitionKind));
      expect(s.transitionBeats, greaterThan(0));
    }
    for (final u in PresetCatalog.universes.values) {
      expect(u.backgrounds, isNotEmpty, reason: 'univers ${u.id} sans fond');
    }
  });

  test('avant chargement : repli Retrofutur × Cosmos', () {
    expect(stylePresetFor('vhs').id, 'retrofutur');
    expect(universePresetFor('miroir').id, 'cosmos');
  });

  test('après chargement : chaque cran a son vrai preset', () {
    PresetCatalog.apply(catalogFile.readAsStringSync());
    expect(stylePresetFor('vhs').id, 'vhs');
    expect(stylePresetFor('vhs').transitionKind, 'cut',
        reason: 'VHS monte en sauts d\'image (brief)');
    expect(stylePresetFor('punk').transitionKind, 'cut',
        reason: 'Punk coupe sec sur le kick (brief)');
    expect(stylePresetFor('psyche').transitionBeats, greaterThanOrEqualTo(8),
        reason: 'Psyché morphe en continu (brief)');
    expect(universePresetFor('nature').backgrounds,
        everyElement(startsWith('nature-')));
    // Id inconnu : toujours le repli, jamais de plantage.
    expect(stylePresetFor('inconnu').id, 'retrofutur');
  });

  test('tous les ids du catalogue existent dans le moteur', () {
    final shaders = shadersFile.readAsStringSync();
    final engine = engineFile.readAsStringSync();
    // Clés déclarées dans BACKGROUNDS / OVERLAYS de shaders.ts.
    Set<String> keysOf(String record) {
      final block = RegExp(
              'export const $record[^{]*\\{([^}]*)\\}',
              dotAll: true)
          .firstMatch(shaders)!
          .group(1)!;
      return RegExp("'([a-z0-9-]+)':")
          .allMatches(block)
          .map((m) => m.group(1)!)
          .toSet();
    }

    final bgIds = keysOf('BACKGROUNDS');
    final motifIds = keysOf('OVERLAYS');
    // Filtres branchés dans engine.ts : this.filters.get('<id>').
    final filterIds = RegExp("filters\\.get\\('([a-z]+)'\\)")
        .allMatches(engine)
        .map((m) => m.group(1)!)
        .toSet();

    final root =
        jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
    for (final MapEntry(:key, :value)
        in (root['styles'] as Map<String, dynamic>).entries) {
      final m = value as Map<String, dynamic>;
      for (final f in m['filters'] as List) {
        expect(filterIds, contains(f), reason: 'filtre "$f" du style $key');
      }
      for (final mo in m['motifs'] as List) {
        expect(motifIds, contains(mo), reason: 'motif "$mo" du style $key');
      }
    }
    for (final MapEntry(:key, :value)
        in (root['universes'] as Map<String, dynamic>).entries) {
      for (final b in (value as Map<String, dynamic>)['backgrounds'] as List) {
        expect(bgIds, contains(b), reason: 'fond "$b" de l\'univers $key');
      }
    }
  });
}
