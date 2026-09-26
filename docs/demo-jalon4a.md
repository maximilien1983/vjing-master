# Démo du jalon 4 — tranches 1 à 3 : styles, univers, Pixabay, FedFlix

## Tranche 4 : boucles VJ (packs Creative Commons)

- 13 boucles « motifs lumineux sur fond noir » dans `catalog/loops/`
  (5,4 Mo), jouées **en surimpression additive** par le moteur, mélangées
  aux motifs shaders (une boucle vidéo max à la fois ; les fonds gardent la
  priorité du budget 2 vidéos décodées).
- **Licences à confirmer (décision produit : validation pack par pack)** :
  - « 3L vj loops series 1 » (archive.org : 3L_sampler_01) — **domaine
    public** (CC Public Domain Dedication). 10 boucles retenues.
  - « 68 Vintage Fairlight VJ Loops » par **VJzoo** (archive.org) —
    **CC-BY 2.5**, attribution à prévoir dans l'écran crédits (jalon 6).
    3 boucles retenues (dont la « photocopie », inversée pour l'additif).
- Chaque boucle est taguée par styles dans le catalogue (ex. spirales →
  70's/Psyché, photocopie → Punk, blocs 8-bit → Retrofutur/VHS).
- Test direct : `?bg=cosmos-stars&loop=<url mp4 encodée>`.

## Tranche 3 : extraits FedFlix et catalogue de clips

- 20 extraits (~12 s) de 4 films domaine public découpés par
  `tools/prepare-clips.mjs` (voir tools/README.md) et hébergés dans
  `catalog/clips/` (servis par Pages) :
  - Machines : « The Drama of Steel » (1946, Bureau of Mines) — coulées,
    laminoir, halle aux fours.
  - Cosmos : « The Eagle Has Landed » (1969, NASA) — décollage Saturn V,
    Lune, la Terre depuis l'espace.
  - Campagne : « A Rural Community: Holtville » (années 40) — fermes,
    chemins, récoltes.
  - Ville : « The City » (1939, musique d'Aaron Copland à l'origine) —
    cheminées, gratte-ciels, trafic.
- `catalog/clips.json` : catalogue tagué généré (univers, époque,
  **luminosité mesurée**, couleur dominante, licence, crédit).
- L'autopilote ne pioche que les clips du catalogue dont la luminosité
  colle au fader **Lumière** (règle du brief) — bouger le fader change le
  bassin de clips.
- Préviz locale avant push : servir aussi le catalogue en local :
  `npx http-server . -p 8124` depuis `catalog/`, et passer
  `--dart-define=CATALOG_URL=http://localhost:8124/`.

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
