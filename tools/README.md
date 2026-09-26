# Tools

## Pipeline de préparation des clips (jalon 4)

`prepare-clips.mjs` lit `clips-manifest.json` et produit les extraits + le
catalogue :

1. Découpe des sources en extraits de ~8 à 15 s. ffmpeg accepte les URL
   http(s) (archive.org) : seules les plages nécessaires sont téléchargées.
2. Normalisation : 854 px de large max (les dérivés 512kb d'archive.org font
   320×240, on garde leur définition), H.264 muet, `+faststart`.
3. Une vignette JPEG par extrait (aperçus de la console).
4. Tags calculés : luminosité moyenne (signalstats YAVG) et couleur dominante
   (frame médiane réduite à 1×1). Univers et époque viennent du manifeste ;
   modèle de vision envisagé plus tard. **Validation manuelle** du JSON avant
   commit (décision produit).
5. Écriture de `/catalog/clips.json` (fusion : `--only <id>` ne touche que
   cette source ; `--force` recompresse).

```
node tools/prepare-clips.mjs [--only steel] [--force]
```

Prérequis : ffmpeg dans le PATH (ou variable `FFMPEG=<chemin>` ;
sur ce poste : `C:\src\ffmpeg\ffmpeg-9.0.2-essentials_build\bin`).

Le choix des segments se fait sur planches-contact : 24 vignettes par film
extraites par seek HTTP puis assemblées (`tools/sheets/`, non versionné) —
voir l'historique des sessions pour la commande.

## sync-renderer.ps1

Copie du build embarqué du moteur vers les assets Flutter (voir le script).
