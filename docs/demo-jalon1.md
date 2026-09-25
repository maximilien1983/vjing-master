# Démo jalon 1 — preuve d'architecture

Objectif : shader qui pulse sur le kick, piloté par la détection de beat au micro, dans la WebView du téléphone puis sur un vrai Chromecast. Mesures de latence et d'i/s à l'écran.

## A. Sur le téléphone (mode local)

1. Sur le téléphone : Paramètres → À propos → taper 7 fois sur « Numéro de build » → Options développeur → activer **Débogage USB**. Brancher en USB, accepter l'empreinte du PC.
2. Sur le PC :

   ```powershell
   cd C:\Claude\vj\vjing-master\app
   flutter devices     # le téléphone doit apparaître
   flutter run
   ```

   (`JAVA_HOME`, `ANDROID_HOME` et le PATH sont déjà configurés au niveau utilisateur ; ouvrir un **nouveau** terminal pour qu'ils soient pris en compte.)

3. Accorder la permission micro au premier lancement.
4. Vérifier, musique lancée dans la pièce :
   - le BPM affiché en haut se stabilise sur le tempo réel (± 2) ;
   - le soleil pulse sur les kicks, les barres L/M/H bougent ;
   - FLASH déclenche un blanc calé sur le beat suivant ;
   - `lat local` reste sous ~30 ms, les i/s ≥ 30 (bouton debug pour l'overlay moteur) ;
   - l'écran reste allumé, l'app reste en paysage.
5. Débogage sans fil ensuite : `adb tcpip 5555` puis `adb connect <ip-du-téléphone>:5555`.

## B. Sur le Chromecast

Préalables : dépôt GitHub poussé + Pages actif (URL du receiver), enregistrement fait dans la Cast Developer Console (docs/cast-setup.md), App ID renseigné dans `app/android/app/src/main/res/values/strings.xml`, propagation attendue (jusqu'à quelques heures), Chromecast redémarré.

1. Téléphone et Chromecast sur le même réseau Wi-Fi.
2. Relancer l'app, toucher l'icône de diffusion, choisir le Chromecast.
3. Vérifier : le visuel apparaît sur la TV et pulse en rythme ; `lat TV` et les i/s TV s'affichent dans le bandeau (les stats remontent du receiver).
4. Mesures à noter pour valider le jalon : latence aller-retour TV, i/s TV, stabilité sur 10 minutes.

## Critères de validation du jalon 1 (brief)

- [ ] Beat détecté au micro sur musique réelle
- [ ] Shader pulse sur le kick en WebView locale
- [ ] Même rendu piloté sur un vrai Chromecast
- [ ] Latence et i/s mesurées et acceptables (≥ 30 i/s sur Chromecast)
