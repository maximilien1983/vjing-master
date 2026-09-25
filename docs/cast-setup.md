# Enregistrer le receiver dans la Google Cast Developer Console

Le receiver n'est pas publié pendant le développement : il faut l'enregistrer et déclarer votre Chromecast comme appareil de test. À faire une fois, au jalon 1.

## 1. Compte développeur Cast

1. Aller sur <https://cast.google.com/publish> avec votre compte Google (celui qui a configuré le Chromecast, c'est plus simple).
2. Payer les frais d'inscription uniques de 5 $ (compte « Google Cast SDK Developer »).

## 2. Déclarer l'application receiver

1. « Add New Application » → **Custom Receiver**.
2. Nom : `VJing Master` (libre).
3. **Receiver Application URL** : `https://maximilien1983.github.io/vjing-master/receiver/` (déployé automatiquement par le workflow Pages).
4. Laisser « Guest Mode » désactivé.
5. Enregistrer → la console fournit un **Application ID** (8 caractères hexadécimaux). Le noter : il se met dans `app/lib/config.dart` (`castAppId`).

## 3. Déclarer le Chromecast de test

1. Trouver le **numéro de série** du Chromecast : imprimé sur l'appareil, ou visible dans l'app Google Home → appareil → Paramètres → « Informations sur l'appareil ».
2. Console Cast → « Add New Device », saisir le numéro de série et une description.
3. Attendre la propagation (**15 minutes à quelques heures** ; parfois un redémarrage du Chromecast est nécessaire : le débrancher 30 s).
4. Important : le Chromecast doit envoyer son numéro de série aux serveurs Google — dans Google Home, vérifier que « Envoyer le numéro de série de l'appareil » est activé dans les paramètres de l'appareil.

## 4. Vérifier

1. Publier le receiver (push sur `main` → GitHub Pages, ou tout autre hébergement HTTPS).
2. Dans l'app, lancer une diffusion : le Chromecast doit charger la page receiver (fond noir puis visuel).
3. En cas d'écran noir immédiat ou de déconnexion : vérifier l'URL déclarée (HTTPS obligatoire, chemin exact), la propagation de l'enregistrement, et le débogage distant Chrome sur `chrome://inspect` (le Chromecast de test expose son WebView).

## Notes

- L'App ID n'est pas un secret, il peut vivre dans le dépôt.
- Tout changement d'URL du receiver dans la console met du temps à se propager ; en développement, préférer une URL stable et pousser le code derrière.
