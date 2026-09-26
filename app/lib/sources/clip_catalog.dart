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

/// Boucle VJ du catalogue (motif lumineux sur fond noir, fusion additive),
/// taguée par styles — les motifs appartiennent aux styles (brief).
class CatalogLoop extends EngineClip {
  final int duree;
  final List<String> styles;
  final String credit;
  final String licence;
  const CatalogLoop(
    super.id,
    super.url, {
    required this.duree,
    required this.styles,
    required this.credit,
    required this.licence,
  });
}

/// Contenu du catalogue hébergé.
class CatalogData {
  final List<CatalogClip> clips;
  final List<CatalogLoop> loops;
  const CatalogData(this.clips, this.loops);
  static const empty = CatalogData([], []);
}

/// Règle du brief : l'autopilote ne pioche que des clips dont la luminosité
/// colle au fader Lumière. Tolérance large : les archives sont surtout
/// sombres, il faut qu'il reste des clips à lumière haute.
bool clipMatchesLight(CatalogClip c, double light) =>
    (light - c.luminosite).abs() <= 0.35;

abstract final class ClipCatalog {
  /// Charge et résout le catalogue depuis l'hébergement statique.
  /// [baseUrl] se termine par `/` (ex. …/vjing-master/catalog/).
  static Future<CatalogData> load(String baseUrl,
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
      return CatalogData.empty;
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Parsing séparé pour les tests. Les URL relatives du catalogue sont
  /// résolues contre [baseUrl].
  static CatalogData parse(String body, String baseUrl) {
    final root = jsonDecode(body) as Map<String, dynamic>;
    String resolve(String url) => url.startsWith('http') ? url : '$baseUrl$url';
    final clips = <CatalogClip>[];
    for (final raw in (root['clips'] ?? const []) as List) {
      final c = raw as Map<String, dynamic>;
      final tags = (c['tags'] ?? const {}) as Map<String, dynamic>;
      clips.add(CatalogClip(
        'cat-${c['id']}',
        resolve(c['url'] as String),
        duree: (c['duree'] as num?)?.toInt() ?? 0,
        univers: (tags['univers'] as String?) ?? '',
        epoque: '${tags['epoque'] ?? ''}',
        luminosite: (tags['luminosite'] as num?)?.toDouble() ?? 0.5,
        couleur: (tags['couleur'] as String?) ?? '#808080',
        credit: (c['credit'] as String?) ?? '',
        licence: (c['licence'] as String?) ?? '',
      ));
    }
    final loops = <CatalogLoop>[];
    for (final raw in (root['loops'] ?? const []) as List) {
      final l = raw as Map<String, dynamic>;
      loops.add(CatalogLoop(
        'loop-${l['id']}',
        resolve(l['url'] as String),
        duree: (l['duree'] as num?)?.toInt() ?? 0,
        styles: List<String>.from((l['styles'] ?? const []) as List),
        credit: (l['credit'] as String?) ?? '',
        licence: (l['licence'] as String?) ?? '',
      ));
    }
    return CatalogData(clips, loops);
  }
}
