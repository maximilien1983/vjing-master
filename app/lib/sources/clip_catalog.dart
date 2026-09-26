import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'clips.dart';

/// Clip du catalogue hébergé (extraits FedFlix pré-découpés, packs de
/// boucles à venir). Généré par tools/prepare-clips.mjs, schéma du brief :
/// url, durée, tags (univers, époque, luminosité, couleur), source,
/// licence, crédit.
class CatalogClip extends EngineClip {
  final int duree;
  final String univers;
  final String epoque;
  final double luminosite; // 0..1
  final String couleur; // #rrggbb dominante
  final String credit;
  final String licence;
  const CatalogClip(
    super.id,
    super.url, {
    required this.duree,
    required this.univers,
    required this.epoque,
    required this.luminosite,
    required this.couleur,
    required this.credit,
    required this.licence,
  });
}

/// Règle du brief : l'autopilote ne pioche que des clips dont la luminosité
/// colle au fader Lumière. Tolérance large : les archives sont surtout
/// sombres, il faut qu'il reste des clips à lumière haute.
bool clipMatchesLight(CatalogClip c, double light) =>
    (light - c.luminosite).abs() <= 0.35;

abstract final class ClipCatalog {
  /// Charge et résout le catalogue depuis l'hébergement statique.
  /// [baseUrl] se termine par `/` (ex. …/vjing-master/catalog/).
  static Future<List<CatalogClip>> load(String baseUrl,
      {http.Client? httpClient}) async {
    final client = httpClient ?? http.Client();
    try {
      final resp = await client
          .get(Uri.parse('${baseUrl}clips.json'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw Exception('clips.json : HTTP ${resp.statusCode}');
      }
      return parse(resp.body, baseUrl);
    } catch (e) {
      debugPrint('Catalogue de clips indisponible : $e');
      return const [];
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Parsing séparé pour les tests. Les URL relatives du catalogue sont
  /// résolues contre [baseUrl].
  static List<CatalogClip> parse(String body, String baseUrl) {
    final root = jsonDecode(body) as Map<String, dynamic>;
    final clips = <CatalogClip>[];
    for (final raw in (root['clips'] ?? const []) as List) {
      final c = raw as Map<String, dynamic>;
      final tags = (c['tags'] ?? const {}) as Map<String, dynamic>;
      final url = c['url'] as String;
      clips.add(CatalogClip(
        'cat-${c['id']}',
        url.startsWith('http') ? url : '$baseUrl$url',
        duree: (c['duree'] as num?)?.toInt() ?? 0,
        univers: (tags['univers'] as String?) ?? '',
        epoque: '${tags['epoque'] ?? ''}',
        luminosite: (tags['luminosite'] as num?)?.toDouble() ?? 0.5,
        couleur: (tags['couleur'] as String?) ?? '#808080',
        credit: (c['credit'] as String?) ?? '',
        licence: (c['licence'] as String?) ?? '',
      ));
    }
    return clips;
  }
}
