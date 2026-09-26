# Pense-bête — à tester et à configurer

Mis à jour au 2026-09-26 (jalons 1-3 codés, jalon 4 en cours).

## À configurer (comptes et sites tiers)

- [x] **Push GitHub** — fait le 2026-09-26 : Pages republie moteur, receiver
  et catalogue automatiquement (workflow, ~30 s + cache ~10 min).
- [ ] **Google Cast Developer Console** (5 $ une fois,
  <https://cast.google.com/publish>) — nécessaire pour valider le jalon 1 sur
  Chromecast réel et tester la console en mode TV. Guide pas à pas :
  `docs/cast-setup.md`. En sortie : un **App ID** à mettre dans
  `app/android/app/src/main/res/values/strings.xml`, et déclarer le numéro de
  série du Chromecast (receiver non publié).
- [x] **Clé API Pixabay** — fournie, rangée dans `secrets/pixabay-key.txt`
  (ignoré par git). Se passe au lancement, voir commandes ci-dessous.
- [ ] *(jalon 5)* **Codemagic** (build iOS) + compte **Apple Developer**
  (99 $/an) pour TestFlight.
- [ ] *(jalon 6)* **Google Play Console** (25 $ une fois) pour le test interne.

## Commandes de lancement

Depuis le push, Pages sert moteur + catalogue : **une seule commande**, sur
PC comme sur téléphone (seule la cible `-d chrome` change) :

```powershell
cd C:\Claude\vj\vjing-master\app
flutter run -d chrome --dart-define=PIXABAY_KEY=$(Get-Content ..\secrets\pixabay-key.txt)
```

(Les serveurs locaux 8123/8124 et RENDERER_URL/CATALOG_URL ne servent plus
qu'à tester des modifs du moteur ou du catalogue avant un push.)

Ouvrir un écran précis pour comparer aux maquettes :
`--dart-define=SCREEN=console|local|sources`.

## À tester — jalon 3 : la console (docs/demo-jalon3.md)

- [ ] Écran Démarrage conforme à la maquette 01 (rotacteurs, fader Lumière,
  tuiles sources, Lancer).
- [ ] Lancer → mode local (sans TV) : vidéo plein écran, plaque BPM en haut à
  droite, poignée CONSOLE.
- [ ] Tiroir : ouverture fluide (~280 ms), **repli seul après 5 s** sans
  interaction, tous les contrôles compacts actifs.
- [ ] Console : faders Énergie / Lumière (l'énergie resserre les changements
  de scène), Flash / Drop / Scène / Suivant / Garder, rotation animée des
  rotacteurs.
- [ ] Écran Sources : charger / décharger, chargement progressif simulé des
  sources distantes, retour Console.
- [ ] Sur téléphone : retour haptique (déclencheurs + crans), BPM et LED
  tempo calés sur la musique.
- [ ] La barre rouge de calibration n'apparaît plus.

## À tester — jalon 4 tranches 1-2 (docs/demo-jalon4a.md)

- [ ] Chaque cran du rotacteur **Univers** change le monde : Campagne, Ville,
  Cosmos, Machines, Nature, Miroir (placeholder en attendant la caméra).
- [ ] Chaque cran du rotacteur **Style** change le traitement : Vintage
  (sépia/grain), 70's (chaud), Punk (photocopie N&B/rouge, coupes sèches),
  Retrofutur, VHS (lignes, sauts, timecode en motif), Psyché (kaléido,
  teinte qui tourne).
- [ ] Avec la clé Pixabay : de **vrais clips vidéo** apparaissent dans les
  univers (mélangés aux shaders), les styles s'appliquent dessus.
- [ ] Un changement d'univers renouvelle les clips ; pas d'écran noir pendant
  le chargement d'un clip.
- [ ] Test direct d'un fond dans le navigateur :
  `http://localhost:8123/?bg=machines-engrenages`, ou d'un clip :
  `?video=<url mp4 encodée>` ; touche `b` en mode dev vite = beat simulé.

## À tester — jalon 4 tranche 3 (FedFlix + catalogue)

- [ ] En Machines / Cosmos / Campagne / Ville : des extraits d'archives
  (Steel 1946, Apollo 11, Holtville, The City 1939) apparaissent dans la
  rotation, mélangés aux shaders et aux clips Pixabay.
- [ ] Le fader **Lumière** change le bassin d'archives (clips sombres en bas,
  clairs en haut) en plus d'assombrir le rendu.
- [ ] Préviz locale avant push : servir le catalogue en plus du moteur :
  `cd catalog && npx http-server . -p 8124` puis ajouter
  `--dart-define=CATALOG_URL=http://localhost:8124/` à la commande flutter.
- [ ] Après le push : tout fonctionne sans les serveurs locaux (Pages sert
  moteur + catalogue + clips).

## En attente / bloqué

- **Validation jalon 1 sur Chromecast réel** : bloquée par la Cast Console
  (ci-dessus).
- **Jalon 2b** (son du téléphone via Visualizer + calibration auto) : se teste
  uniquement sur téléphone, prévu après le jalon 4.
- **Publication (jalon 6)** : revoir l'hébergement des clips Pixabay (les
  conditions de l'API interdisent le hotlinking permanent pour une app
  publiée — bascule possible vers des copies sur R2).
