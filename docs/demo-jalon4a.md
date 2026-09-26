# Démo du jalon 4 — tranches 1 et 2 : styles, univers, fonds Pixabay

Les rotacteurs de la console pilotent maintenant de vrais presets : chaque
cran change réellement le rendu. Et les univers piochent de **vrais clips
vidéo Pixabay** en plus des shaders (tranche 2). Restent : FedFlix, boucles
CC, fichiers du téléphone, catalogue tagué.

## Tranche 2 : fonds vidéo

- Le moteur lit des clips mp4 (muets, en boucle, recadrés cover 854 × 480,
  2 décodés max) et les fond avec les shaders ; les styles s'appliquent
  par-dessus (un clip de trafic en VHS ressemble à une VHS).
- Chaque univers a ses requêtes Pixabay prédéfinies dans
  `catalog/presets.json` (ex. Ville : « city night traffic », « neon
  street »). L'autopilote mélange shaders et clips ; un clip illisible est
  banni automatiquement (message `bgerror`).
- **Clé API** : jamais dans le dépôt. La passer au lancement :
  `flutter run -d chrome --dart-define=PIXABAY_KEY=<ta clé>`
  (pratique : mettre la clé dans `secrets/pixabay-key.txt`, ignoré par git,
  puis `--dart-define=PIXABAY_KEY=$(Get-Content ..\secrets\pixabay-key.txt)`).
  Sans clé, les univers restent en shaders seuls.
- Conditions Pixabay vérifiées : recherches mises en cache 24 h (fait),
  quota ~100 req/min (loin d'être atteint : ~3 requêtes par changement
  d'univers). Lecture directe depuis le CDN assumée pour l'usage perso ;
  à revoir avant publication (jalon 6, bascule possible vers copies R2).
- Test direct moteur : `?video=<url mp4 encodée>` (banc URL).

## Ce qui change

- **6 univers** (fonds du moteur) :
  - Campagne : collines au crépuscule, champ de blé au vent, ciel de nuages.
  - Ville : skyline nocturne à fenêtres, traînées de trafic, pluie sur néons.
  - Cosmos : soleil rétro, étoiles, nébuleuse, tunnel (inchangé).
  - Machines : engrenages, pistons, circuits imprimés.
  - Nature : caustiques d'eau, fumée, lucioles.
  - Miroir : kaléidoscope et chrome liquide **en attendant la caméra
    (jalon 5)**.
- **6 styles** (filtres + montage + motifs, conformes au tableau du brief) :
  - Vintage : grain, vignettage, sépia ; fondus lents ; poussières, cercles.
  - 70's : tons chauds + halo ; fondus lents ; spirale, ondes.
  - Punk : photocopie noir/blanc/rouge, glitch ; coupes sèches ; trame, éclats.
  - Retrofutur : bloom, chroma ; grilles, soleils, boucles néon (inchangé).
  - VHS : lignes, bruit, bavure couleur, sauts d'image ; timecode, tracking.
  - Psyché : kaléidoscope, rotation de teinte continue ; mandala, fluide.
- Les presets viennent de `/catalog/presets.json` (copie embarquée dans
  l'app) : modifiables sans recompiler, comme demandé dans le brief.
- Les motifs appartiennent désormais aux styles (brief), plus aux univers.

## Préviz PC

Le moteur hébergé sur Pages n'est **pas encore à jour** (push en attente) :
pointer la préviz sur un moteur local.

```
cd renderer && npx http-server dist -p 8123
cd app && flutter run -d chrome --dart-define=RENDERER_URL=http://localhost:8123/
```

Tourner les rotacteurs Style et Univers pendant que la musique joue ; chaque
cran doit changer les fonds, les filtres et les motifs. Test direct d'un fond
dans le navigateur : `http://localhost:8123/?bg=machines-engrenages`, d'un
style : `?bg=ville-trafic&filters=vhs:0.9&motifs=timecode,tracking`
(touche `b` : beat simulé 124 BPM en mode dev vite).

## Téléphone Android

`flutter run` : le moteur embarqué est à jour dans les assets, rien d'autre à
faire. Sur Chromecast en revanche, le receiver Pages servira l'ancien moteur
tant que le push n'est pas fait.

## Reste du jalon 4 (tranches suivantes)

- Vraies sources vidéo dans le moteur (`background.kind: "video"`), lecture
  des fichiers chargés dans l'écran Sources.
- Pixabay (clé API à fournir par --dart-define), FedFlix hébergé, packs de
  boucles CC, catalogue de clips tagué.
- Aperçus vivants des sources dans la console.
