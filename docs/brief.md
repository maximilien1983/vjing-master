# Mission

Tu vas développer « VJing Master », une app mobile perso (iOS et Android) de VJing automatique. L'app écoute la musique et génère en continu une vidéo live qui réagit au rythme. Elle s'affiche sur le téléphone ou est diffusée sur une TV via Chromecast ou AirPlay. L'utilisateur règle quelques paramètres, l'autopilote fait le reste.

Design des écrans (réalisé avec Claude Design) : [LIEN DU DESIGN]

Le design fait référence pour l'interface : reproduis-le fidèlement (disposition, matières, typographie, couleurs, états).

# Mode de travail

- Avant d'écrire du code, lis tout ce brief et le design, puis pose-moi en une seule fois toutes les questions nécessaires pour trancher ce qui reste ouvert (voir « Points à trancher »). Si un choix technique a plusieurs options raisonnables, propose ta recommandation argumentée plutôt que de me demander de choisir à froid.
- Avance par jalons (voir « Jalons »). À la fin de chaque jalon, fais-moi une démo testable sur téléphone et attends mon feu vert avant le suivant.
- Le jalon 1 est une preuve d'architecture : ne développe rien d'autre tant qu'il n'est pas validé sur un vrai Chromecast.
- N'embarque aucun contenu vidéo dont la licence n'est pas vérifiée. En cas de doute, demande-moi.
- Aucun secret dans le dépôt (clé API Pixabay passée par `--dart-define` ou fichier local ignoré par git).

# Environnement de développement

- Mon poste de développement tourne sous Linux (pas de Mac).
- Android : tests directs depuis Linux, téléphone en USB puis en débogage sans fil, `flutter run` avec hot reload. Les jalons 1 à 4 se valident sur Android.
- iOS : compilation impossible sous Linux. Prévois un build iOS via un service cloud (par exemple Codemagic) avec distribution TestFlight, ou un Mac si j'en dispose d'ici là. Configure ce pipeline au plus tard avant le jalon 5.
- Chromecast : receiver non publié pendant le développement, donc à déclarer dans la Google Cast Developer Console avec le numéro de série de mon Chromecast. Guide-moi pour cette étape au jalon 1.
- Micro, caméra, capture audio et AirPlay ne se testent que sur appareils réels.

# Spécifications fonctionnelles

## Principe

L'utilisateur choisit un style, un univers et un niveau de lumière, puis lance. La vidéo est entièrement autonome : l'autopilote choisit les clips de fond, ajoute et retire des boucles superposées, applique des filtres, le tout calé sur la musique. Les interventions manuelles en live sont un bonus.

Contexte d'usage : soirées à la maison, TV du salon, connexion internet toujours disponible (pas de mode hors ligne). App gratuite, sans pub ni achat intégré, sans backend applicatif.

## Paramètres

**Style (6)** : le traitement visuel. Chaque style est un preset de filtres, palette, rythme de montage et motifs, applicable à tout univers.

| Style | Filtres | Palette | Montage | Motifs |
| --- | --- | --- | --- | --- |
| Vintage | Grain, vignettage, sépia léger | Tons chauds délavés | Fondus lents | Formes simples, poussières |
| 70's | Saturation douce, halo | Orange, brun, moutarde | Fondus et zooms lents | Spirales, ondes |
| Punk | Photocopie, contraste extrême, glitch | Noir, blanc, rouge | Coupes sèches sur le kick | Collages, trames |
| Retrofutur | Bloom, décalage chromatique | Magenta, cyan | Transitions nettes sur la mesure | Grilles, soleils, boucles néon |
| VHS | Lignes, décalage couleur, bruit | Couleurs baveuses | Sauts d'image | Texte d'écran, timecode |
| Psyché | Kaléidoscope, feedback, rotation de teinte | Arc-en-ciel saturé | Morphing continu | Mandalas, fluides |

**Univers (6)** : ce que l'on voit. Chaque univers définit les requêtes de sources et les tags recherchés.

| Univers | Sources principales |
| --- | --- |
| Campagne | Films ruraux FedFlix, paysages et champs Pixabay |
| Ville | Rues, trafic, néons Pixabay, archives urbaines FedFlix |
| Cosmos | Archives spatiales FedFlix, shaders étoiles et nébuleuses |
| Machines | Films industriels FedFlix, engrenages et usines Pixabay |
| Nature | Eau, fumée, végétal, animaux Pixabay |
| Miroir | Caméra du téléphone, filmant la soirée |

**Lumière** : curseur de dark à lumineux. Règle exposition, contraste, saturation, et oriente vers des clips sombres ou clairs.

**Énergie** : fader 0 à 100. Valeurs de départ à calibrer :

| Paramètre | Énergie 0 | Énergie 100 |
| --- | --- | --- |
| Changement de fond | Toutes les 32 mesures | Toutes les 4 mesures |
| Boucles superposées simultanées | 0 | 4 |
| Intensité des filtres | 20 % | 100 % |
| Réaction au beat | Légère respiration | Pulsation forte sur chaque kick |

## Déclencheurs manuels

| Déclencheur | Effet | Durée |
| --- | --- | --- |
| Flash | Inversion ou blanc plein écran, calé sur le prochain beat | 1 temps |
| Drop | Coupe au noir, puis énergie et filtres au maximum | 4 mesures, puis retour progressif |
| Scène | Nouveau fond et nouvelles boucles, calés sur le prochain temps 1 | Immédiat |
| Suivant | Zappe le clip de fond en cours et l'écarte pour la session | Immédiat |
| Garder | Prolonge le clip en cours et favorise des clips proches | Jusqu'au prochain appui |

## Règles de l'autopilote

- Ne pioche que des clips dont les tags correspondent à l'univers et à la lumière choisis.
- Dérive doucement à l'intérieur des réglages (sous-thèmes, intensité, motifs) sans en sortir.
- Toutes les transitions sont quantifiées sur la mesure de 4 temps.
- Historique des 10 derniers clips pour éviter les répétitions.
- Boucles superposées : apparition et disparition en fondu, positions aléatoires.
- Sans beat détecté : dérive lente, fondus longs, aucune pulsation.
- Montée d'énergie détectée dans la musique : changements plus rapprochés, même à énergie constante.
- Changement de paramètre en live : transition douce sur 1 à 2 mesures.

## Modes d'affichage

| Mode | Où tourne le rendu | Écran du téléphone | Plateformes |
| --- | --- | --- | --- |
| Local | WebView sur le téléphone | Vidéo plein écran, console en tiroir | iOS, Android |
| Chromecast | Receiver web sur le Chromecast | Console complète | iOS, Android |
| AirPlay | WebView sur le téléphone, affichée en second écran | Console complète | iOS |

Bascule automatique dès qu'une sortie TV est connectée ou déconnectée. En mode local, la console arrive en tiroir depuis le bas et se replie après 5 secondes d'inactivité.

## Interface (voir le design)

Paysage verrouillé, thème sombre, esthétique table de mixage analogique années 70 (aluminium brossé, bois).

Éléments : rotacteurs style et univers, faders lumière et énergie, boutons à LED Flash, Drop et Scène, touches Suivant et Garder, aperçus des sources chargées (fond et boucles en cours), LED tempo et afficheur BPM, moniteur d'aperçu du rendu, voyant On Air, bouton de diffusion. Écran de démarrage avec choix des paramètres et bouton Lancer. Pas de VU-mètres audio : on mixe des vidéos, ce sont les aperçus des sources qui occupent cette place.

Exigences :

- cibles tactiles de 48 points minimum ;
- retour haptique aux crans et sur les déclencheurs ;
- animations mécaniques réalistes (touches qui s'enfoncent, faders avec inertie) ;
- écran maintenu allumé pendant la session.

## Sources vidéo

- **Pixabay** (API REST vidéos, clé) : fonds, requêtes prédéfinies par univers, résultats mis en cache. Vérifie les conditions d'utilisation de l'API (cache, hotlinking, quotas) et adapte l'implémentation.
- **FedFlix** (Internet Archive, domaine public) : fonds rétro, sous forme d'extraits pré-découpés listés dans un catalogue.
- **Packs de boucles VJ sous Creative Commons** (motifs lumineux sur fond noir) : convertis et hébergés en statique, licence à confirmer par pack avec moi.
- **Shaders génératifs** : fonds et motifs, codés dans le moteur.
- **Caméra du téléphone** : univers Miroir, en mode local et AirPlay uniquement en V1.
- Écran « Sources et crédits » listant auteurs et licences.

## Sources audio

Le micro est le mode par défaut, car il fonctionne partout et avec n'importe quelle source (enceinte, vinyle, DJ). Android propose en plus une écoute directe du son joué par le téléphone. Le choix se fait dans les réglages de l'app.

| Source | Plateformes | Principe | Limites |
| --- | --- | --- | --- |
| Micro | iOS, Android | Capte la musique dans la pièce | Sensible au bruit ambiant et aux voix |
| Son du téléphone, via l'API Visualizer | Android | Spectre et forme d'onde du son global, avec la seule permission micro | Qualité modeste, comportement variable selon les constructeurs |
| Son du téléphone, via la capture de lecture (repli) | Android 10 et plus | Enregistre l'audio des autres apps (AudioPlaybackCapture), autorisation à chaque session | Certaines apps de streaming bloquent la capture, Spotify à tester |

- Sur iOS, seul le micro est proposé : le système interdit d'écouter le son des autres apps. Le contournement par extension de diffusion d'écran (ReplayKit) est écarté.
- **Calibration du décalage** : en mode Son du téléphone avec une enceinte Bluetooth, le signal capté arrive 150 à 300 ms avant le son audible. Un réglage de décalage retarde les visuels d'autant. Il se calibre en tapant en rythme sur la musique et reste mémorisé par sortie audio.

# Spécifications techniques

## Architecture

Toute l'intelligence tourne dans l'app Flutter. Le moteur de rendu est une page web WebGL « muette » qui affiche l'état qu'on lui envoie. Un seul moteur sert les trois sorties :

- **mode local** : moteur dans une WebView plein écran ;
- **Chromecast** : moteur servi comme Custom Web Receiver (CAF Receiver SDK), qui reçoit les messages sur un namespace custom ;
- **AirPlay** : moteur dans une WebView native affichée sur l'écran externe (second écran iOS), la console restant sur le téléphone.

## Dépôt (monorepo proposé, ajuste si besoin)

- `/app` : app Flutter (console, audio, autopilote, sources, sorties).
- `/renderer` : moteur TypeScript + WebGL2, build Vite, un seul bundle réutilisé en WebView et en receiver.
- `/receiver` : enveloppe Cast (CAF) autour du moteur.
- `/tools` : pipeline ffmpeg de préparation des clips et génération du catalogue.
- `/catalog` : catalogue JSON et presets (styles, univers), hébergés en statique.

## Moteur de rendu

- Calques : 0 fond (vidéo ou shader, fondu enchaîné sur 1 mesure), 1 à 4 boucles superposées (position, échelle, rotation, opacité, pulsation), filtres globaux (chaîne de 1 à 3), déclencheurs (flash, coupe au noir).
- Transparence des boucles par mode de fusion écran ou addition (clips sur fond noir), sans canal alpha.
- Filtres V1 : noir et blanc, sépia, grain, VHS, glitch, kaléidoscope, feedback, posterize, bloom, inversion, photocopie, rotation de teinte.
- Rendu interne 854 × 480, mis à l'échelle ; 30 i/s minimum y compris sur Chromecast ; 2 vidéos décodées simultanément au maximum.
- Le moteur extrapole les beats à partir du BPM et de la phase reçus, en appliquant le décalage de calibration.
- Le moteur renvoie à l'app de quoi afficher les aperçus des sources chargées dans la console (identifiants et vignettes des clips en cours).

## Protocole app vers moteur (JSON, identique pour les trois cibles)

```json
{"type": "scene", "state": {"background": {}, "overlays": [], "filters": [], "transition": {}}}
{"type": "beat", "bpm": 124.0, "phase": 0.25, "t0": 1727190000123, "offsetMs": 0}
{"type": "levels", "low": 0.82, "mid": 0.40, "high": 0.21}
{"type": "trigger", "id": "drop"}
```

- `beat` : envoyé à chaque changement et au moins toutes les 2 s.
- `levels` : 10 à 15 fois par seconde, débit à valider sur Chromecast.
- Documente le schéma complet dans `/renderer` et versionne-le.

## Analyse audio (sur le téléphone uniquement)

- Capture micro 44,1 ou 48 kHz avec gain automatique ; ou son du téléphone sur Android (Visualizer, puis AudioPlaybackCapture en repli).
- FFT 1 024 à 2 048 points, environ 40 analyses par seconde.
- Bandes lissées : basses 20 à 150 Hz, médiums 150 Hz à 2 kHz, aigus 2 à 16 kHz.
- Détection d'attaques par flux spectral (priorité aux basses pour résister aux voix et au bruit), BPM par autocorrélation, phase dans la mesure.
- Détection de structure (calme, montée, drop) par variation d'énergie sur 8 à 16 mesures.
- Implémentation native si nécessaire pour la performance (AVAudioEngine et vDSP sur iOS, AudioRecord, Visualizer et AudioPlaybackCapture sur Android), exposée à Flutter par platform channels.

## Sorties

- **Chromecast** : plugin Flutter si un plugin supporte correctement les messages sur namespace custom, sinon platform channels natifs (Cast SDK iOS et Android). Receiver servi en HTTPS, enregistré dans la Google Cast Developer Console.
- **AirPlay** : détection de l'écran externe, fenêtre dédiée avec WKWebView sur l'écran externe, sélecteur de sortie AirPlay natif. Code natif iOS.
- Bouton de diffusion unique dans la console, qui propose les sorties disponibles.

## Catalogue et pipeline

- Script ffmpeg : découpe (2 à 10 s), conversion 480p H.264 sans audio, génération d'une vignette (utilisée aussi pour les aperçus de la console).
- Catalogue JSON unique : URL, durée, tags (univers, époque, luminosité moyenne, couleur dominante), source, licence, crédit.
- Presets JSON séparés pour les styles et les univers, modifiables sans recompiler l'app.
- Hébergement statique avec en-têtes CORS permettant l'usage des vidéos comme textures WebGL.

## Qualité

- Tests unitaires sur l'autopilote (sélection par tags, quantification, historique) et sur la détection de tempo (fichiers audio de référence).
- Mode debug affichant BPM, phase, niveaux et état de scène en surimpression.
- Mesure des i/s sur Chromecast affichable en debug.

# Jalons

1. **Preuve d'architecture** : moteur WebGL minimal avec un shader qui pulse sur le kick, affiché dans la WebView et sur un Chromecast, piloté par l'app avec la détection de beat réelle au micro. Mesurer latence et i/s. Testé sur Android.
2. **Audio et autopilote minimal** : analyse audio complète (micro et son du téléphone sur Android, calibration du décalage), autopilote sur un seul réglage (Retrofutur et Cosmos, 100 % shaders).
3. **Console** : interface complète conforme au design, tous les contrôles branchés.
4. **Sources et paramètres** : Pixabay, catalogue FedFlix, packs de boucles, catalogue tagué, les 6 styles et 6 univers.
5. **iOS, AirPlay et caméra** : pipeline de build iOS, second écran natif, univers Miroir.
6. **Publication** : bêta TestFlight et test interne Google Play, écran crédits, permissions micro et caméra justifiées.

# Points à trancher avec moi

- Énergie : fader manuel seul, ou mode automatique qui suit l'intensité de la musique ?
- Un seul choix par axe, ou mélange possible (deux univers à la fois) ?
- Tagging du catalogue : manuel, ou assisté par un modèle de vision ?
- Extraits FedFlix : hébergement d'une copie, ou lecture depuis Internet Archive (CORS, fiabilité) ?
- Hébergement statique du moteur, du receiver et du catalogue : quel service ?
- Build iOS : service cloud ou Mac ?
- Console en mode local : tiroir escamotable (prévu) ou écran partagé ?
- Tout autre point que le design ou ce brief laissent ambigu.
