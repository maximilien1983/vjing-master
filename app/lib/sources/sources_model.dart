import 'dart:async';

import 'package:flutter/foundation.dart';

/// Type d'une source vidéo.
enum SourceKind { camera, file, remote }

/// État de chargement.
enum SourceState { unloaded, loading, loaded }

/// Aperçu peint (pas encore de vraie vidéo au jalon 3).
enum PreviewArt { camera, neonTunnel, super8, storm, expo }

class VideoSource {
  final String id;
  final String name; // nom complet (écran Sources)
  final String shortName; // étiquette des vignettes
  final String meta;
  final SourceKind kind;
  final bool loop;
  final PreviewArt art;
  SourceState state;
  double progress; // 0-1 pendant le chargement

  VideoSource({
    required this.id,
    required this.name,
    required this.shortName,
    required this.meta,
    required this.kind,
    required this.art,
    this.loop = false,
    this.state = SourceState.unloaded,
    this.progress = 0,
  });
}

/// Sources de la session. Jalon 3 : données factices conformes aux maquettes ;
/// le vrai catalogue (Pixabay, FedFlix, fichiers) arrive au jalon 4.
class SourcesModel extends ChangeNotifier {
  final List<VideoSource> sources = [
    VideoSource(
      id: 'camera',
      name: 'Caméra du téléphone',
      shortName: 'CAMÉRA',
      meta: 'Direct · objectif arrière',
      kind: SourceKind.camera,
      art: PreviewArt.camera,
      state: SourceState.loaded,
    ),
    VideoSource(
      id: 'neon-tunnel',
      name: 'neon-tunnel.mp4',
      shortName: 'NEON-TUNNEL',
      meta: 'Sur le téléphone · 0:12',
      kind: SourceKind.file,
      art: PreviewArt.neonTunnel,
      loop: true,
      state: SourceState.loaded,
    ),
    VideoSource(
      id: 'super8-plage',
      name: 'super8-plage-1974.mov',
      shortName: 'SUPER8-PLAGE',
      meta: 'Sur le téléphone · 1:48',
      kind: SourceKind.file,
      art: PreviewArt.super8,
      loop: true,
      state: SourceState.loaded,
    ),
    VideoSource(
      id: 'expo-1970',
      name: 'expo-universelle-1970.mp4',
      shortName: 'EXPO-1970',
      meta: 'Distant · archive.org · 4:05',
      kind: SourceKind.remote,
      art: PreviewArt.expo,
      loop: true,
    ),
    VideoSource(
      id: 'orage-lent',
      name: 'orage-lent.webm',
      shortName: 'ORAGE-LENT',
      meta: 'Distant · 2:30',
      kind: SourceKind.remote,
      art: PreviewArt.storm,
      loop: true,
    ),
  ];

  final Map<String, Timer> _loaders = {};

  List<VideoSource> get loaded =>
      sources.where((s) => s.state == SourceState.loaded).toList();

  int get loadedCount => loaded.length;

  /// Bascule chargée / non chargée. Les sources distantes passent par un
  /// chargement progressif (simulé au jalon 3, vrai téléchargement au 4).
  void toggle(VideoSource s) {
    switch (s.state) {
      case SourceState.loaded:
        s.state = SourceState.unloaded;
      case SourceState.loading:
        cancel(s);
        return;
      case SourceState.unloaded:
        if (s.kind == SourceKind.remote) {
          _startLoading(s);
        } else {
          s.state = SourceState.loaded;
        }
    }
    notifyListeners();
  }

  void _startLoading(VideoSource s) {
    s.state = SourceState.loading;
    s.progress = 0;
    _loaders[s.id]?.cancel();
    _loaders[s.id] = Timer.periodic(const Duration(milliseconds: 120), (t) {
      s.progress += .04;
      if (s.progress >= 1) {
        t.cancel();
        _loaders.remove(s.id);
        s.state = SourceState.loaded;
        s.progress = 0;
      }
      notifyListeners();
    });
  }

  void cancel(VideoSource s) {
    _loaders.remove(s.id)?.cancel();
    s.state = SourceState.unloaded;
    s.progress = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _loaders.values) {
      t.cancel();
    }
    _loaders.clear();
    super.dispose();
  }
}
