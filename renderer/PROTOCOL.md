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

`background.kind` : `shader` | `video` (V1 jalon 1 : `shader` uniquement).
`overlays`, `filters` : vides au jalon 1, schéma détaillé au jalon 2+.

### `beat` — horloge musicale

```json
{"type": "beat", "bpm": 124.0, "phase": 0.25, "t0": 1727190000123, "offsetMs": 0, "confidence": 0.9}
```

- `bpm` : tempo détecté. `bpm = 0` ⇒ pas de beat détecté (dérive lente, aucune pulsation).
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
{"type": "trigger", "id": "flash"}
```

`id` : `flash` | `drop` | `scene` | `next` | `keep`. Jalon 1 : `flash` seul.

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

### `pong`

Réponse à `{"type":"ping","t":...}` : `{"type":"pong","t":<t reçu>,"tr":<epoch ms réception>}`. Sert à mesurer la latence app → moteur.
