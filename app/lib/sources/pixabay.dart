import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'clips.dart';

/// Client de l'API vidéos Pixabay (jalon 4).
///
/// Conditions d'utilisation vérifiées (docs API, 2026) : clé obligatoire,
/// résultats à mettre en cache 24 h (fait ci-dessous, en mémoire), quota
/// ~100 requêtes / minute. Les URL des clips sont servies par
/// cdn.pixabay.com avec CORS ouvert (vérifié), donc utilisables en texture
/// WebGL. Lecture directe depuis le CDN assumée pour cet usage perso ;
/// à re-évaluer avant toute publication (jalon 6) — bascule possible vers
/// des copies hébergées (R2), comme pour FedFlix.
class PixabayClip extends EngineClip {
  final int duration; // secondes
  final String tags;
  // id 'px-<id pixabay>', url mp4 ~960×540 (tiny), adaptée au 854×480.
  const PixabayClip(super.id, super.url, this.duration, this.tags);
}

class PixabayClient {
  final String key;
  final http.Client _http;
  final Map<String, (DateTime, List<PixabayClip>)> _cache = {};

  PixabayClient(this.key, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Recherche mise en cache 24 h (exigence de l'API).
  Future<List<PixabayClip>> search(String query, {int perPage = 20}) async {
    final cached = _cache[query];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(hours: 24)) {
      return cached.$2;
    }
    final uri = Uri.https('pixabay.com', '/api/videos/', {
      'key': key,
      'q': query,
      'per_page': '$perPage',
      'safesearch': 'true',
      'video_type': 'film',
    });
    final resp = await _http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Pixabay ${resp.statusCode} : ${resp.body}');
    }
    final clips = parse(resp.body);
    _cache[query] = (DateTime.now(), clips);
    return clips;
  }

  /// Parsing séparé pour les tests. Prend la variante `tiny` (~960×540),
  /// repli `small`, et ignore les clips trop courts (< 4 s, boucles nettes
  /// improbables).
  static List<PixabayClip> parse(String body) {
    final root = jsonDecode(body) as Map<String, dynamic>;
    final clips = <PixabayClip>[];
    for (final hit in root['hits'] as List) {
      final h = hit as Map<String, dynamic>;
      final videos = h['videos'] as Map<String, dynamic>;
      final variant =
          (videos['tiny'] ?? videos['small']) as Map<String, dynamic>?;
      final url = variant?['url'] as String?;
      final duration = (h['duration'] as num?)?.toInt() ?? 0;
      if (url == null || url.isEmpty || duration < 4) continue;
      clips.add(PixabayClip(
        'px-${h['id']}',
        url,
        duration,
        (h['tags'] as String?) ?? '',
      ));
    }
    return clips;
  }

  void dispose() {
    _http.close();
    _cache.clear();
  }
}

/// Charge les clips d'un univers : quelques résultats par requête prédéfinie,
/// mélangés pour varier les scènes d'une session à l'autre.
Future<List<PixabayClip>> clipsForQueries(
  PixabayClient client,
  List<String> queries, {
  int perQuery = 4,
}) async {
  final clips = <PixabayClip>[];
  final seen = <String>{};
  for (final q in queries) {
    try {
      final found = (await client.search(q)).toList()..shuffle();
      var added = 0;
      for (final c in found) {
        if (seen.add(c.id)) {
          clips.add(c);
          added++;
        }
        if (added >= perQuery) break;
      }
    } catch (e) {
      debugPrint('Pixabay "$q" : $e');
    }
  }
  return clips;
}
