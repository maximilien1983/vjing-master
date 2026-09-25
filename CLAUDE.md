# VJing Master

App mobile perso (iOS + Android) de VJing automatique : elle écoute la musique (micro ou son du téléphone) et génère en continu une vidéo live calée sur le rythme, affichée sur le téléphone ou diffusée sur TV (Chromecast, AirPlay). Brief complet : `docs/brief.md`.

## Monorepo

- `/app` : app Flutter (console, analyse audio, autopilote, sources, sorties).
- `/renderer` : moteur TypeScript + WebGL2, build Vite, un seul bundle réutilisé en WebView et en receiver. Le protocole app→moteur est documenté et versionné dans `renderer/PROTOCOL.md`.
- `/receiver` : enveloppe Cast (CAF Receiver) autour du moteur.
- `/tools` : pipeline ffmpeg de préparation des clips et génération du catalogue.
- `/catalog` : catalogue JSON et presets (styles, univers), hébergés en statique.

## Interface

- L'UI suit `docs/design/DESIGN.md` (tokens, composants, états, comportements).
- Les maquettes `docs/design/screens/*.html` font foi pour les valeurs visuelles exactes ; les `*.png` (@3x, 844 × 390 pt) servent de référence et de base de comparaison visuelle.
- Le HTML est une spécification, pas du code à transposer : on implémente en widgets Flutter, tokens centralisés dans `lib/theme/vj_tokens.dart`.
- App en paysage uniquement, thème sombre uniquement, cibles tactiles de 48 pt minimum.
- Avant de coder un écran, lire son HTML et son PNG ; après, comparer le rendu (golden test ou capture) au PNG.

## Décisions actées (2026-09-25)

- Énergie : fader manuel, avec la réactivité intégrée du brief (montée détectée → changements plus rapprochés). Pas de mode Auto en V1.
- Un seul choix par axe (style, univers). Pas de mélange en V1.
- Tagging du catalogue : assisté par modèle de vision (luminosité/couleur calculées par ffmpeg), validation manuelle du JSON.
- Console en mode local : tiroir escamotable (maquettes 05/06), repli après 5 s d'inactivité.
- FedFlix : copie pré-découpée hébergée (domaine public), pas de lecture directe depuis Internet Archive.
- Hébergement statique : GitHub Pages (moteur, receiver, catalogue). Surveiller les limites (~1 Go / 100 Go/mois) ; bascule possible des vidéos vers Cloudflare R2 si besoin.
- Build iOS : Codemagic + TestFlight (pipeline à monter avant le jalon 5).
- Poste de dev : Windows 11 (ce PC). Android via USB puis débogage sans fil, `flutter run` avec hot reload.

## Règles

- Aucun secret dans le dépôt : clé API Pixabay passée par `--dart-define` ou fichier local ignoré par git.
- Aucun contenu vidéo embarqué sans licence vérifiée ; en cas de doute, demander.
- Avancer par jalons ; démo testable sur téléphone à la fin de chaque jalon, feu vert avant le suivant.
- Rendu moteur : interne 854 × 480 mis à l'échelle, ≥ 30 i/s y compris sur Chromecast, 2 vidéos décodées simultanément max.
- Toutes les transitions quantifiées sur la mesure de 4 temps.
