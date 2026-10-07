# Protocole app → moteur

**Version : 1** (champ `v` optionnel sur chaque message ; absent = 1). Toute évolution incompatible incrémente la version, le moteur reste rétrocompatible d'une version.

Le moteur est « muet » : il ne fait qu'afficher l'état reçu. Un seul point d'entrée pour les trois cibles :

```js
window.VJM.handleMessage(msg)   // msg : objet JSON ou chaîne JSON
```

- **Mode local (WebView)** : l'app appelle `handleMessage` via `runJavaScript`.
- **Chromecast** : le receiver CAF relaie tel quel les messages du namespace `urn:x-cast:fr.vjm.control` vers `handleMessage`.
- **AirPlay** : WebView sur l'écran externe, même mécanisme que le mode local.

Le moteur remonte des infos (stats, clips en cours pour les aperçus console) via `window.VJM.onFeedback = (msg) => ...`, que chaque enveloppe branche vers l'app (JS channel `VjmFeedback` en WebView, message Cast en receiver).

## Messages entrants

### `scene` — état visuel cible

```json
{"type": "scene", "state": {
  "background": {"kind": "shader", "id": "pulse-sun", "params": {}},
  "overlays": [],
  "filters": [],
  "transition": {"kind": "crossfade", "beats": 4}
}}
```

`background.kind` : `shader` | `video` | `camera`.

Fond caméra : `{"kind": "camera", "id": "camera"}` (id réservé, pas d'url).
Le moteur ouvre la caméra de l'appareil via `getUserMedia` (`facingMode:
environment`) : webcam en préviz PC, objectif arrière sur téléphone. Recadrée
en cover comme un clip, elle compte dans le budget de décodage (2 vidéos max).
La transition attend la première frame, sans délai limite (l'invite de
permission peut rester ouverte) ; refus ou absence de caméra ⇒ message
sortant `bgerror` id `camera`. L'iframe de préviz doit déléguer la permission
(`allow="camera"`). Banc d'essai : `?camera=1`, touche `c` en dev.

Fond vidéo : `{"kind": "video", "id": "px-21118", "url": "https://…/x.mp4"}`.
Le clip doit être servi avec CORS (`crossorigin`), il est lu muet en boucle,
recadré en cover sur 854 × 480, lumière et styles appliqués comme aux
shaders. Le moteur garde **2 vidéos décodées maximum** (courante + suivante) ;
la transition attend que le clip soit décodable (pas d'écran noir). Clip
illisible ⇒ message sortant `bgerror` (l'app bannit et rejoue).

Clips **portrait** (reels du catalogue, gardés verticaux) : le cadrage
paysage est interne au moteur, sans message dédié — chaque nouveau clip
vertical reçoit en rotation l'un des trois traitements : bandes noires,
duo miroir (deux copies côte à côte, la droite inversée), fond flouté
(le clip sur lui-même étendu, flouté et assombri). Banc d'essai :
`?cadrage=bandes|duo|fond-flou`.

`background.id` (shaders, par univers) :
- Cosmos : `cosmos-sun`, `cosmos-stars`, `cosmos-nebula`, `cosmos-rings`
- Campagne : `campagne-collines`, `campagne-ble`, `campagne-nuages`
- Ville : `ville-skyline`, `ville-trafic`, `ville-pluie`
- Machines : `machines-engrenages`, `machines-pistons`, `machines-circuits`
- Nature : `nature-eau`, `nature-fumee`, `nature-lucioles`
- Miroir (placeholders, caméra au jalon 5) : `miroir-kaleido`, `miroir-chrome`

`overlays[]` : `{iid, motif, x, y, scale, rot, pulse}`. Motifs (par style,
« motion graphics » discrets) : `lightleak`, `poussieres`, `vumetre`
(Vintage) ; `lightleak`, `bokeh`, `speaker` (70's) ; `oscillo`, `trame`,
`speaker` (Punk) ; `grid`, `loop`, `flare` (Retrofutur) ; `timecode`,
`tracking`, `oscillo` (VHS) ; `mandala`, `fluide`, `bokeh` (Psyché).
Toujours disponibles mais hors presets : `sun`, `cercles`, `spirale`,
`onde`, `eclats`. Id inconnu ⇒ repli `grid`.

Motif vidéo (boucle VJ sur fond noir, fusion additive) :
`{iid, kind: "video", url, x, y, scale, rot, pulse}`. Le budget de décodage
privilégie les fonds : au-delà de 2 vidéos actives, la boucle est mise en
pause sur sa dernière frame. L'app n'envoie qu'une boucle vidéo à la fois.

`filters[]` : `{id, intensity, pulse}` avec `intensity` ∈ [0, 1] et `pulse`
∈ [0, 1] optionnel (0 par défaut) : pulsation de l'intensité sur le beat —
0 = constante, 1 = l'effet ne vit que sur les temps (enveloppe interne du
moteur, retombée ~180 ms). Le moteur lisse l'intensité de base (~250 ms)
pour que les enchaînements d'effets restent fluides. Depuis le 2026-10-07
l'autopilote n'envoie plus de motifs superposés : il séquence ces filtres
(1 à 3 à la fois, intensités et pulsations aléatoires, pauses) ; les motifs
restent supportés pour les bancs d'essai. Ids :
`bloom`, `chroma` (Retrofutur) ; `grain`, `vignette`, `sepia` (Vintage) ;
`warmth` (70's, inclut le halo) ; `photocopy`, `glitch` (Punk) ; `vhs`
(lignes + bruit + bavure + sauts) ; `kaleido`, `huerot` (Psyché — `huerot`
est une vitesse de rotation de teinte) ; `posterize`, `hue` (génériques).
Id inconnu ⇒ ignoré.

### `beat` — horloge musicale

```json
{"type": "beat", "bpm": 124.0, "phase": 0.25, "t0": 1727190000123, "offsetMs": 0, "confidence": 0.9}
```

- `bpm` : tempo détecté. `bpm = 0` ⇒ pas de beat détecté (dérive lente, aucune pulsation).
  Depuis le 2026-10-07 l'app ne l'envoie plus en pratique : sans détection elle
  se cale sur un BPM de secours de 120 (moyenne usuelle, confiance 0), grille
  ancrée sur l'horloge epoch. Le moteur reste compatible avec `bpm = 0`.
- `phase` : position dans la **mesure de 4 temps**, ∈ [0, 1) — 0 = temps 1, 0.25 = temps 2…
- `t0` : horodatage epoch ms auquel `phase` était valable (horloge de l'émetteur).
- `offsetMs` : décalage de calibration (positif = retarder les visuels).
- Le moteur **extrapole** : `phase(t) = (phase + (t - t0 - offsetMs) / 60000 * bpm / 4) mod 1`.
- Envoyé à chaque changement et au moins toutes les 2 s (sert aussi de resynchro d'horloge).

### `levels` — niveaux lissés

```json
{"type": "levels", "low": 0.82, "mid": 0.40, "high": 0.21}
```

10 à 15 fois par seconde. Valeurs ∈ [0, 1]. `low` pilote la pulsation.

### `trigger` — déclencheur ponctuel

```json
{"type": "trigger", "id": "strobe", "on": true}
```

`id` : `flash` | `drop` | `strobe` | `negative` | `zoom` | `shake` | `echo` | `rewind`.

`on` (effets maintenables) : `true` à l'appui, `false` au relâchement. Un tap
garantit l'effet pendant **une mesure complète** (2 s sans beat) ; maintenu,
l'effet dure jusqu'au relâchement. Sans `on` : équivaut à un tap.

- `flash` : éclair blanc calé sur le prochain temps (immédiat sans beat).
- `drop` : coupe au noir (envoyé par l'autopilote sur montée détectée).
- `strobe` : stroboscope blanc/noir, 2 éclats par temps.
- `negative` : inversion des couleurs de toute l'image.
- `zoom` : plongée au centre de l'image, pulsée sur le beat.
- `shake` : secousse de l'image, amplifiée sur le beat.
- `echo` : traînée fantôme (feedback vidéo, fusion éclaircissante).
- `rewind` : rembobinage ~5 s, visuel VHS pendant le cycle ; les clips vidéo
  sautent en arrière (en rebouclant par la fin), les shaders remontent le
  temps. Maintenu : les rembobinages s'enchaînent.

### `config` — réglages du moteur

```json
{"type": "config", "debug": true, "energy": 0.6, "light": 0.5}
```

`debug` : overlay BPM / phase / niveaux / i/s.

## Messages sortants (`onFeedback`)

### `stats`

```json
{"type": "stats", "fps": 59.6, "renderMs": 3.1, "droppedFrames": 0, "t": 1727190002000}
```

Émis 1×/s quand `debug` est actif, sert à mesurer les i/s sur Chromecast.

### `sources` (à partir du jalon 4)

Identifiants et vignettes des clips en cours, pour les aperçus de la console.

### `bgerror`

```json
{"type": "bgerror", "id": "px-21118", "reason": "erreur vidéo"}
```

Fond vidéo illisible (réseau, CORS, format) : l'app doit bannir ce clip pour
la session et pousser une autre scène.

### `pong`

Réponse à `{"type":"ping","t":...}` : `{"type":"pong","t":<t reçu>,"tr":<epoch ms réception>}`. Sert à mesurer la latence app → moteur.
