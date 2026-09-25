# VJing Master · spécification d'interface (Flutter)

Référence visuelle de l'app. Les maquettes HTML de `screens/` font foi pour toutes les valeurs visuelles (couleurs, tailles, ombres, positions). Les PNG associés (rendus @3x) servent de référence rapide et de base de comparaison une fois l'écran codé.

Les maquettes sont statiques : elles montrent des états, pas de logique. Le HTML se lit comme une spécification, il ne se transpose pas tel quel en Flutter.

---

## 1. Principes

- **Objet :** une table de mixage analogique des années 70, haut de gamme. Façade en aluminium brossé graphite, joues en noyer, sérigraphie crème, voyants ambrés. Sans surcharge décorative.
- **Usage :** en soirée, dans la pénombre. Thème sombre uniquement, éléments actifs lumineux.
- **Rôle du téléphone :** console de pilotage. La vidéo générée part vers la TV (Chromecast, AirPlay) ou s'affiche en plein écran sur le téléphone (mode local).
- **Orientation :** paysage uniquement (`SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])`), mode immersif.
- **Référence de mise en page :** iPhone paysage, 844 × 390 pt. Tout est dessiné à cette taille. Voir §7 pour les autres tailles.

## 2. Écrans

| Fichier | Écran | États représentés |
|---|---|---|
| `01-demarrage` | Démarrage | Style, univers, lumière, sélection des sources (chargée / non chargée), bouton Lancer, voyant Prêt |
| `02-console-veille` | Console, TV non connectée | On Air éteint, déclencheurs au repos, Garder inactif |
| `03-console-on-air` | Console, diffusion TV | On Air allumé, Drop enfoncé et allumé, Garder actif, icône de diffusion active |
| `04-sources` | Sources vidéo | Source chargée, non chargée, en cours de chargement (progression + Annuler), étiquette Boucle |
| `05-local-tiroir-ferme` | Mode local | Vidéo plein écran, poignée « Console », plaque BPM + sources + diffusion |
| `06-local-tiroir-ouvert` | Mode local, tiroir ouvert | Console compacte par-dessus la vidéo, Flash enfoncé, Garder actif |

Navigation :

```
Démarrage --Lancer--> Console (TV connectée)   ou   Mode local (pas de TV)
Console   --toucher une vignette source--> Sources (choix de la source de cette vignette)
Mode local --poignée--> tiroir ouvert / fermé
Mode local --touche cassette--> Sources
Console / Mode local --bouton diffusion--> sélecteur Chromecast / AirPlay
```

## 3. Tokens

À centraliser dans `lib/theme/vj_tokens.dart` (constantes) et une `ThemeExtension<VjColors>`.

### Couleurs

| Token | Valeur | Usage |
|---|---|---|
| `ground` | `#0B0B0C` | fond hors façade |
| `aluTop` / `aluMid` / `aluBottom` | `#3A3B3F` / `#2F3034` / `#27282B` | dégradé vertical de la façade |
| `recessTop` / `recessBottom` | `#141416` / `#1B1B1E` | zones enfoncées (bandeau sources, liste, fenêtres) |
| `walnut` | `#22130A` `#4A2B18` `#5B3720` `#432716` `#1F1108` | dégradé horizontal des joues (5 stops) |
| `print` | `#E9DFC7` | sérigraphie principale |
| `printDim` | `#B8AD95` | sérigraphie secondaire, crans non sélectionnés |
| `pointer` | `#F3EAD3` | index des boutons et des faders |
| `amberCore` / `amberHi` / `amberEdge` | `#FFB547` / `#FFF1C9` / `#D9741A` | LED allumée (dégradé radial) |
| `amberLabel` | `#FFC166` | texte sélectionné, afficheurs |
| `amberGlow` | `rgba(255,170,60,.6)` | halo des LED |
| `ledOff` | `#5A3D1D` → `#24170A` | LED éteinte |
| `lensOff` | `#4A3620` → `#211608`, texte `#EADCC0` | déclencheur au repos |
| `lensOn` | `#FFF4D2` → `#FFC35C` → `#F08A1F` → `#C05F10`, texte `#4A2305` | déclencheur allumé |
| `onAirOn` | `#FF8A66` → `#E8301E` → `#A3150C`, texte `#FFF3E6` | On Air allumé |
| `onAirOff` | `#4A1A15` → `#1C0806`, texte `#B36A5C` | On Air éteint |
| `nixieDigit` / `nixieGlow` | `#FFB566` / `#FF7B1C` | chiffres BPM |
| `keyTop` / `keyBottom` / `keyEdge` | `#3F4044` / `#2A2B2E` / `#121214` | touches mécaniques |

Règle de couleur : l'ambre signale ce qui est actif, le rouge est réservé à On Air. Pas d'autre couleur d'accent dans la console (les vignettes vidéo portent leurs propres couleurs).

### Typographie

- **Barlow Condensed** (300 à 700), toute l'interface. Petites capitales : `toUpperCase()` + `letterSpacing` de 0.14 à 0.34 em selon le rôle.
- **Allura** (400), uniquement pour la signature gravée « VJing Master ».
- Chargement : package `google_fonts`, ou mieux, polices embarquées dans `assets/fonts/` (licence OFL) pour ne pas dépendre du réseau en soirée.

| Style | Taille / graisse / espacement | Usage |
|---|---|---|
| `sectionTitle` | 11–12 pt / 600 / 0.26 em | STYLE, UNIVERS, ÉNERGIE, SOURCES |
| `crankLabel` | 9.5–10.5 pt / 600 / 0.1 em | noms des crans |
| `lensLabel` | 15 pt (13 compact) / 600–700 / 0.16 em | FLASH, DROP, SCÈNE |
| `keyLabel` | 12 pt / 600 / 0.24 em | SUIVANT, GARDER, touches d'écran |
| `hint` | 10–11 pt / 500 / 0.14 em, `printDim` | aides (« Toucher pour changer ») |
| `nixie` | 38 pt (26 compact) / 300 | BPM |
| `wordmark` | Allura 25 pt (36 au démarrage) | signature gravée |

### Rayons, ombres, lueurs

- Rayons : touches 6, déclencheurs 9 (lentille 4), vignettes 5, panneaux enfoncés 8–10, tiroir 16 (haut).
- Relief d'une touche : `BoxShadow(offset: (0,3), color: keyEdge)` + `BoxShadow(offset: (0,5), blur: 8, black 50%)` + liseré clair 1 px en haut. Enfoncée : décalage `translateY` de 2 à 5 pt et ombre réduite à 1 px.
- Creux : ombre interne (voir §4) + liseré clair 1 px en bas.
- Lueur d'une LED ou d'une lentille allumée : 2 `BoxShadow` ambrés (blur 6 spread 2, puis blur 14).
- Gravure (signature) : texte `print` à 80 %, ombre noire 1 px au-dessus, reflet blanc 12 % 1 px en dessous.

## 4. Matières : implémentation conseillée

| Matière | Approche Flutter |
|---|---|
| Alu brossé | Texture PNG répétable @3x (lignes horizontales fines) posée sur le `LinearGradient` aluTop → aluBottom, ou `CustomPainter` qui trace des lignes 1 px d'opacité variable. Ajouter un reflet horizontal léger (dégradé blanc 3–5 %). |
| Noyer | Texture PNG verticale @3x recommandée (le grain se simule mal en dégradés). Ombre interne côté façade. |
| Creux | Flutter n'a pas d'ombre interne native : `CustomPainter` (path évidé + `MaskFilter.blur`) ou package `flutter_inset_shadow`. |
| Jupe crantée des boutons | `SweepGradient` à arrêts alternés tous les 5° (`#151517` / `#2C2C30`). Chapeau métal : `SweepGradient` gris clair / gris foncé. |
| Tubes Nixie | Conteneur arrondi en haut, grille nid d'abeille en `CustomPainter` à faible opacité, chiffre fantôme « 8 » à 7 %, chiffre allumé avec `Shadow` multiples. |
| Lignes de balayage (vidéos) | Overlay `CustomPainter` : une ligne noire 1 px toutes les 3 px, 12 à 22 % d'opacité. |

Préférer des `RepaintBoundary` autour des éléments statiques (joues, façade) et isoler ce qui s'anime (LED tempo, aperçus vidéo).

## 5. Composants

Dimensions en pt, à la taille de référence.

| Widget | Taille | États | Notes |
|---|---|---|---|
| `VjScaffold` | plein écran | · | Joues noyer 36 pt à gauche et à droite (elles occupent les zones d'encoche et des coins arrondis), façade entre les deux, marge basse 22 pt pour l'indicateur d'accueil. |
| `RotarySelector` | cadran 156 × 106, bouton 60 (72 au démarrage, 48 en compact) | 6 crans, 1 sélectionné | Crans à −150°, −90°, −30°, 30°, 90°, 150° (0° en haut). Repère gravé + LED par cran, LED ambrée et libellé `amberLabel` sur le cran choisi. Geste : glisser en rotation avec aimantation sur les crans, ou toucher un libellé. Version compacte : pas de libellés, fenêtre ambrée sous le bouton avec le nom du cran. |
| `VerticalFader` | Lumière 56 × 164, Énergie 68 × 336 ; curseur 48 × 26 / 52 × 30 | valeur 0–1 | Rainure 6 pt, graduations des deux côtés. Lumière : « Lumineux » en haut, « Dark » en bas. Énergie : 0 à 100 tous les 10. **Toute la colonne** est tactile, pas seulement le curseur. |
| `LedTriggerButton` | 86 × 84 (84 × 64 compact) | repos, enfoncé + allumé | Flash, Drop, Scène : déclencheurs ponctuels. La lentille s'allume à l'appui puis retombe (durée à définir avec le moteur vidéo). |
| `IndicatorKey` | 135 × 48 | inactif, actif (voyant allumé) | Suivant (momentané), Garder (bascule). Voyant 14 × 8. |
| `OnAirLamp` | 68 × 38 | éteint, allumé | Allumé quand une TV est connectée et reçoit le flux. |
| `CastButton` | 48 × 48 | inactif (icône crème), actif (icône ambrée) | Ouvre le sélecteur natif Chromecast / AirPlay. |
| `NixieDisplay` | 3 tubes 34 × 46 | · | BPM détecté. `TempoLed` 10 pt à côté, clignote à chaque temps (voir §6). |
| `SourceThumbnail` | cadre 96 × 58, écran 88 × 50 | à l'image, chargée hors image | Aperçu vivant de la source. Liseré et LED ambrés si l'autoplay l'utilise en ce moment. Icône d'échange. **Toucher = changer la source de cette vignette.** |
| `VideoMonitor` | 200 × 120, écran 186 × 106 | · | Aperçu de la sortie TV (texture vidéo réduite), reflet vitre + vignettage. |
| `SourceRow` | hauteur 60 | chargée, non chargée, chargement (progression, Annuler) | Écran Sources. Icône de type (caméra, fichier, distant), nom, méta, étiquette Boucle pour les fichiers, touche d'action 128 × 48. |
| `SourceTile` | 88 × 72 | chargée, non chargée | Démarrage : toucher pour charger ou décharger. Tuile « Ajouter » en fin de rangée. |
| `ConsoleDrawer` | hauteur 200, poignée 176 × 30 dans une zone tactile de 48 | fermé, ouvert | Mode local. Glisse depuis le bas par-dessus la vidéo, ombre portée vers le haut. |
| `PowerButton` | 116 | prêt | Bouton Lancer : lunette crantée, anneau ambré, symbole marche. Voyant Prêt au-dessus. |
| `EngravedWordmark` | · | · | « VJing Master » en Allura, effet gravé (§3). |

## 6. Comportements

- **LED tempo :** allumée franchement sur le temps puis s'éteint rapidement (environ 20 % de la période allumée, fondu jusqu'à 45 %). Période = 60 / BPM. À caler sur l'horloge de détection, pas sur un timer libre.
- **Déclencheurs :** retour haptique léger à l'appui (`HapticFeedback.lightImpact`), enfoncement visuel de 5 pt.
- **Garder :** bascule ; fige la scène en cours tant que le voyant est allumé.
- **Suivant :** passe immédiatement à la scène suivante.
- **Rotacteurs :** clic haptique (`selectionClick`) à chaque cran.
- **Aperçus :** vignettes et moniteur affichent des textures vidéo réduites ; limiter leur fréquence d'image (15 à 24 i/s) pour épargner la batterie.
- **Tiroir :** animation de 250 à 300 ms en `easeOutCubic` ; glisser la poignée vers le bas pour fermer.

## 7. Adaptation aux autres tailles

- La composition de référence est 844 × 390. Sur un écran plus large, les joues restent à 36 pt et la façade s'étire : répartir l'espace dans les écarts entre groupes, sans grossir les composants.
- Sur un écran plus bas (en dessous d'environ 360 pt), réduire d'abord la hauteur du fader Énergie et du bandeau sources.
- Respecter `MediaQuery.padding` : les joues doivent couvrir au minimum l'encart de sécurité latéral.

## 8. Accessibilité

- Cibles tactiles de 48 pt minimum partout.
- `Semantics` sur chaque contrôle : libellé + valeur (« Style : 70's », « Énergie : 72 », « Drop, enfoncé »).
- Contraste : `print` et `printDim` passent 4.5:1 sur la façade ; le texte d'On Air éteint est volontairement plus faible mais reste lisible.
- Ne pas coder un état par la seule couleur : un élément actif change aussi de luminosité et, pour les touches, de profondeur.

## 9. Hors maquettes (à décider)

- Écran Sources ouvert depuis une vignette : aujourd'hui une liste charger / décharger ; à faire évoluer en sélecteur (« Vignette 2 : changer la source », touche Choisir).
- Plus de 3 sources chargées sur la console (défilement ou sources à l'image seulement) ; plus de 4 au démarrage.
- Banques en ligne (Pixabay, archives FedFlix, shaders génératifs) dans la liste des sources.
- États d'erreur : TV perdue, fichier distant inaccessible, micro ou caméra refusés.
- Écran de sélection de la TV (le sélecteur natif suffit peut-être).
