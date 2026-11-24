# Roadmap des sources vidéo (rotacteur SOURCE)

Consigné le 2026-11-24, après la refonte « simplification UI ». Objectif à
terme : **toutes les sources diffusables sur Chromecast**, y compris la caméra
du téléphone et les vidéos personnelles.

## État livré (2026-11-24)

Le rotacteur SOURCE (8 crans) remplace UNIVERS sur les trois écrans :
Crazy AI, Urban, Cosmos, Nature, Tools, Dance, **Cam**, **My List**.
Les six premiers crans sont les univers historiques (ids catalogue inchangés :
`miroir`, `ville`, `cosmos`, `nature`, `machines`, `danse`).

- **Cam** (livré, mode local uniquement) : permission CAMERA demandée à la
  sélection (`permission_handler` + manifest), fond `{kind: camera}` épinglé
  dans l'autopilote (`setPinnedBackground` : rotation des fonds suspendue,
  effets et motifs continuent), repli sur le dernier univers si refus,
  `bgerror`, ou connexion cast. Le cran est **grisé en diffusion**
  (`sourceDisabledNotches`) : le moteur qui tourne sur la TV n'a pas accès à
  la caméra du téléphone.
- **My List** (reporté, cran grisé partout) : vidéos personnelles de la
  galerie du téléphone jouées en fond dans un ordre aléatoire.

## T5 — My List (à faire)

1. **Sélection** : picker de vidéos de la galerie (`file_picker` ou
   `image_picker`), écran de gestion (liste vide par défaut, ajout /
   suppression) qui remplace l'écran Sources factice du jalon 3
   (`SourcesScreen`, `SourcesModel`).
2. **Stockage** : copie des fichiers choisis dans le dossier de l'app
   (persistance entre sessions), liste en JSON local.
3. **Lecture** : la WebView charge le moteur depuis les assets — les URI
   `content://` de la galerie sont d'une autre origine et l'upload WebGL
   serait bloqué (CORS). Solution : **mini serveur HTTP dans l'app**
   (`HttpServer` dart:io) servant les copies avec `Access-Control-Allow-
   Origin: *`. En local : lié à `127.0.0.1`. Le moteur lit des URL comme il
   le fait déjà pour Pages — aucun changement moteur.
4. **Aléatoire** : le pool de l'autopilote fait déjà une rotation aléatoire
   avec historique — brancher les clips My List comme pool exclusif.
5. **Chromecast** : lier le serveur à `0.0.0.0` et pousser des URL sur l'IP
   **LAN** du téléphone : le receiver charge alors les fichiers directement
   sur le réseau local. Dégriser le cran en cast à ce moment-là.

## T4 bis — Caméra sur Chromecast (jalon 5+)

Le receiver est une page web exécutée **par le Chromecast** : il ne peut pas
ouvrir la caméra du téléphone. Pour un flux caméra sur la TV il faut streamer :

- **Voie recommandée : WebRTC.** L'app capture la caméra (getUserMedia dans
  la WebView locale ou plugin natif), établit une PeerConnection avec le
  receiver ; la signalisation passe par le canal de messages Cast déjà en
  place (`CastLink`). Latence faible, adapté au VJing.
- Alternative : encodage HLS/MJPEG servi sur le LAN (même serveur que My
  List) — plus simple mais latence de plusieurs secondes, peu adapté.

Tant que ce n'est pas livré, le cran Cam reste grisé en diffusion et la
session revient automatiquement au dernier univers quand le cast se connecte
(`Session.setSource` + listener `cast.states`).

## Garde-fous existants à réutiliser

- `sourceDisabledNotches({required bool castConnected})` dans
  `app/lib/autopilot/presets.dart` : seul endroit qui décide des crans grisés.
- `Autopilot.setPinnedBackground` : tout fond « piloté par la source » (cam,
  et sans doute My List exclusif) passe par là.
- `bgerror` (PROTOCOL.md) : le repli d'une source spéciale se joue dans le
  handler de `Session.start`.
