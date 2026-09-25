# Tools

Pipeline de préparation des clips (à partir du jalon 4) :

1. Découpe des sources en extraits de 2 à 10 s (ffmpeg), conversion 480p H.264 sans audio.
2. Génération d'une vignette par extrait (aussi utilisée par les aperçus de la console).
3. Tags assistés : luminosité moyenne et couleur dominante calculées (ffmpeg), univers/époque proposés par un modèle de vision, **validation manuelle** avant intégration au catalogue.
4. Génération du catalogue JSON (`/catalog`).

Prérequis : ffmpeg dans le PATH.
