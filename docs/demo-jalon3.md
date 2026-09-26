# Démo du jalon 3 — Console

La console « table de mixage 70's » remplace le bandeau technique des
jalons 1-2. Maquettes de référence : `docs/design/screens/01…06`.

## Préviz PC (Chrome)

```
cd app
flutter run -d chrome
```

- L'app s'ouvre sur l'écran **Démarrage** (maquette 01) : rotacteurs Style /
  Univers, fader Lumière, tuiles sources (toucher = charger / décharger),
  bouton **Lancer**.
- Sans TV (cas du web), Lancer ouvre le **mode local** (maquette 05) : vidéo
  plein écran, plaque BPM en haut à droite, poignée **CONSOLE** en bas.
- La poignée ouvre le **tiroir** (maquette 06) : rotacteurs compacts avec
  fenêtre ambrée, faders Lumière / Énergie, Flash / Drop / Scène,
  Suivant / Garder. Il se replie seul après 5 s sans interaction.
- La touche cassette de la plaque ouvre l'écran **Sources** (maquette 04) :
  charger / décharger, chargement progressif simulé des sources distantes.
- Pour ouvrir un écran directement (comparaison aux maquettes) :
  `flutter run -d chrome --dart-define=SCREEN=console|local|sources`

## Téléphone Android

```
cd app
flutter run
```

- Mêmes écrans ; accorder le micro pour voir BPM (tubes Nixie), LED tempo
  calée sur le temps, et l'autopilote réagir.
- Avec un Chromecast déclaré (docs/cast-setup.md) : Lancer ouvre la
  **console** (maquettes 02/03). Brancher la TV via le bouton diffusion ;
  **On Air** s'allume en rouge, l'icône de diffusion passe à l'ambre.
  Depuis le mode local, la connexion d'une TV bascule vers la console.

## À vérifier pour le feu vert

- Fidélité visuelle aux 6 maquettes (rendu comparé aux PNG @3x).
- Tous les contrôles agissent sur le moteur : faders (Énergie resserre les
  changements de scène, Lumière assombrit), Flash / Drop / Scène / Suivant,
  Garder (fige la scène), rotacteurs (crans non câblés = repli
  Retrofutur × Cosmos en attendant le jalon 4).
- Retour haptique : appui léger sur les déclencheurs, clic à chaque cran.
- Tiroir : ouverture ~280 ms, repli automatique après 5 s.

## Limites connues (prévues pour les jalons suivants)

- Les aperçus des sources sont peints (pas de vraies textures vidéo) et
  l'autoplay n'utilise pas encore les sources chargées : jalon 4.
- Fichier / Lien de l'écran Sources : jalon 4.
- Un seul couple Style × Univers réel (Retrofutur × Cosmos) : jalon 4.
- AirPlay et calibration auto du décalage : jalons 5 / 2b.
