# VJing Master

App mobile perso (iOS + Android) de VJing automatique : elle écoute la musique et génère en continu une vidéo live qui réagit au rythme, sur le téléphone ou sur TV (Chromecast, AirPlay).

## Structure

| Dossier | Rôle |
| --- | --- |
| `app/` | App Flutter : console, analyse audio, autopilote, sources, sorties |
| `renderer/` | Moteur TypeScript + WebGL2 (Vite), un bundle pour WebView et receiver — protocole dans `renderer/PROTOCOL.md` |
| `receiver/` | Enveloppe Cast (CAF Receiver) autour du moteur |
| `tools/` | Pipeline ffmpeg de préparation des clips et du catalogue |
| `catalog/` | Catalogue JSON et presets, servis en statique |
| `docs/` | Brief (`docs/brief.md`) et design (`docs/design/`) |

## Développement

```sh
# Préviz complète sur PC (app + micro + moteur en iframe, dans Chrome)
cd app && flutter run -d chrome

# Moteur seul (http://localhost:5173 — touches : b = beat simulé, d = debug, f = flash)
cd renderer && npm install && npm run dev

# Receiver (nécessite un vrai Chromecast enregistré, voir docs/cast-setup.md)
cd receiver && npm install && npm run build

# App (téléphone Android branché en USB, débogage activé)
cd app && flutter run
```

La préviz PC utilise le vrai micro (autoriser Chrome), la vraie détection de BPM et le moteur hébergé sur Pages dans une iframe. Chromecast et retour haptique sont inactifs sur le web ; après un changement du moteur, pousser sur `main` pour que l'iframe le voie (ou utiliser `npm run dev` pour itérer sur le moteur seul).

Le déploiement du moteur, du receiver et du catalogue sur GitHub Pages est automatique à chaque push sur `main` (`.github/workflows/pages.yml`).
