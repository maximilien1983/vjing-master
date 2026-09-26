/// Presets des styles et univers. Le catalogue JSON (/catalog/presets.json,
/// copie embarquée dans assets/catalog/) fait foi ; les constantes ci-dessous
/// servent de repli tant qu'il n'est pas chargé.
///
/// Brief « Paramètres » : un style = filtres + montage + motifs ; un univers
/// = ce que l'on voit (fonds ; clips vidéo à venir dans la suite du jalon 4).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config.dart';

class StylePreset {
  final String id;
  final List<String> filterIds; // filtres du moteur (voir PROTOCOL.md)
  final String transitionKind; // 'crossfade' | 'cut'
  final int transitionBeats;
  final List<String> motifs; // motifs superposés du moteur
  const StylePreset(this.id, this.filterIds, this.transitionKind,
      this.transitionBeats, this.motifs);
}

class UniversePreset {
  final String id;
  final List<String> backgrounds; // fonds shaders du moteur
  final List<String> queries; // requêtes Pixabay prédéfinies (brief)
  const UniversePreset(this.id, this.backgrounds, [this.queries = const []]);
}

/// Repli : Retrofutur × Cosmos (jalons 1-3), utilisés avant le chargement
/// du catalogue et si un id inconnu arrive.
const retrofutur = StylePreset(
    'retrofutur', ['bloom', 'chroma'], 'crossfade', 2, ['grid', 'loop', 'flare']);

const cosmos = UniversePreset(
  'cosmos',
  ['cosmos-sun', 'cosmos-stars', 'cosmos-nebula', 'cosmos-rings'],
);

/// Les 6 crans de chaque rotacteur (ordre des maquettes : angles −150° à 150°).
const styleIds = ['vintage', '70s', 'punk', 'retrofutur', 'vhs', 'psyche'];
const styleLabels = ['Vintage', "70's", 'Punk', 'Retrofutur', 'VHS', 'Psyché'];
// « Danse » a remplacé « Campagne » (demande utilisateur, 2026-09-26) :
// boucles de gens qui dansent dans des styles très variés.
const universeIds = ['danse', 'ville', 'cosmos', 'machines', 'nature', 'miroir'];
const universeLabels = ['Danse', 'Ville', 'Cosmos', 'Machines', 'Nature', 'Miroir'];

/// Catalogue chargé depuis le JSON embarqué (et plus tard rafraîchi depuis
/// l'hébergement statique, avec le catalogue de clips).
abstract final class PresetCatalog {
  static Map<String, StylePreset> styles = {'retrofutur': retrofutur};
  static Map<String, UniversePreset> universes = {'cosmos': cosmos};
  static bool loaded = false;

  /// Réseau d'abord (presets modifiables sans recompiler, brief), puis copie
  /// embarquée, puis constantes de repli.
  static Future<void> load() async {
    if (loaded) return;
    try {
      final resp = await http
          .get(Uri.parse('${catalogUrl}presets.json'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        apply(utf8.decode(resp.bodyBytes));
        return;
      }
      debugPrint('Presets réseau : HTTP ${resp.statusCode}, repli asset');
    } catch (e) {
      debugPrint('Presets réseau indisponibles ($e), repli asset');
    }
    try {
      apply(await rootBundle.loadString('assets/catalog/presets.json'));
    } catch (e) {
      debugPrint('Presets : catalogue illisible, repli Retrofutur×Cosmos ($e)');
    }
  }

  /// Parse et installe un catalogue. Séparé de load() pour les tests.
  static void apply(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    final s = <String, StylePreset>{};
    for (final MapEntry(:key, :value)
        in (root['styles'] as Map<String, dynamic>).entries) {
      final m = value as Map<String, dynamic>;
      final t = m['transition'] as Map<String, dynamic>;
      s[key] = StylePreset(
        key,
        List<String>.from(m['filters'] as List),
        t['kind'] as String,
        t['beats'] as int,
        List<String>.from(m['motifs'] as List),
      );
    }
    final u = <String, UniversePreset>{};
    for (final MapEntry(:key, :value)
        in (root['universes'] as Map<String, dynamic>).entries) {
      final m = value as Map<String, dynamic>;
      u[key] = UniversePreset(
        key,
        List<String>.from(m['backgrounds'] as List),
        List<String>.from((m['pixabay'] ?? const []) as List),
      );
    }
    styles = s;
    universes = u;
    loaded = true;
  }

  @visibleForTesting
  static void reset() {
    styles = {'retrofutur': retrofutur};
    universes = {'cosmos': cosmos};
    loaded = false;
  }
}

StylePreset stylePresetFor(String id) => PresetCatalog.styles[id] ?? retrofutur;

UniversePreset universePresetFor(String id) =>
    PresetCatalog.universes[id] ?? cosmos;
