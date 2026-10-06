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

Sources verticales (reels) : normalisées à 480 px de haut, en gardant leur
orientation. Le cadrage paysage (bandes noires, duo miroir, fond flouté)
est appliqué par le moteur au moment du rendu — même fichier, traitements
variés par l'autopilote (décision 2026-10-06).

```
node tools/prepare-clips.mjs [--only steel] [--force]
```

Prérequis : ffmpeg dans le PATH (ou variable `FFMPEG=<chemin>` ;
sur ce poste : `C:\src\ffmpeg\ffmpeg-9.0.2-essentials_build\bin`).

Le choix des segments se fait sur planches-contact : 24 vignettes par film
extraites par seek HTTP puis assemblées (`tools/sheets/`, non versionné) —
voir l'historique des sessions pour la commande.

## fetch-instagram.mjs

Récupère les vidéos d'une liste d'URL de posts/reels Instagram (fichier
`tools/instagram-urls.txt` ou CSV, une URL par ligne — gitignoré) vers
`tools/sources/instagram/` (gitignoré aussi : les bruts ne vont jamais dans
le dépôt, seuls les extraits normalisés par `prepare-clips.mjs` sont
publiés).

```
node tools/fetch-instagram.mjs [--list <fichier>] [--browser firefox]
```

- Session connectée obligatoire (collections perso). Deux options :
  cookies lus dans Firefox, ou export `tools/instagram-cookies.txt`
  (extension « Get cookies.txt LOCALLY » — sur Windows les cookies Chrome
  sont illisibles directement, chiffrement app-bound).
- Rythme lent volontaire (8-20 s entre vidéos) pour ne pas faire
  restreindre le compte ; `archive.txt` évite les re-téléchargements.
- Licences : contenus du domaine public avec accord écrit des titulaires
  des comptes, accords conservés hors dépôt ; renseigner `licence` et
  `credit` dans le manifeste.
- Prérequis : yt-dlp (`winget install yt-dlp.yt-dlp`).

Ensuite : déclarer les fichiers locaux comme sources dans
`clips-manifest.json` (ffmpeg accepte les chemins locaux comme les URL)
et relancer `prepare-clips.mjs`.

## sync-renderer.ps1

Copie du build embarqué du moteur vers les assets Flutter (voir le script).
