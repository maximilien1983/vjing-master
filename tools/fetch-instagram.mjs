#!/usr/bin/env node
// Récupération des vidéos Instagram listées dans tools/instagram-urls.txt
// (ou .csv : toute ligne contenant une URL instagram.com est prise, le reste
// est ignoré). Les MP4 bruts vont dans tools/sources/instagram/ (gitignoré) ;
// ils sont ensuite référencés comme sources locales dans clips-manifest.json
// et passent par prepare-clips.mjs comme n'importe quelle autre source.
//
// Usage : node tools/fetch-instagram.mjs [--list <fichier>] [--browser firefox]
//
// Authentification (collections perso : session connectée obligatoire) :
// - tools/instagram-cookies.txt présent (export « cookies.txt » du
//   navigateur, gitignoré) -> utilisé en priorité ;
// - sinon cookies lus dans Firefox (--browser pour en changer).
//   Attention : Chrome est illisible sur Windows (chiffrement app-bound),
//   passer par l'export cookies.txt dans ce cas.
//
// Prérequis : yt-dlp dans le PATH (winget install yt-dlp.yt-dlp) ou
// YTDLP=<chemin>. Rythme volontairement lent (pause 8-20 s entre vidéos)
// pour ne pas faire restreindre le compte de la session.

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const ytdlp = process.env.YTDLP ?? 'yt-dlp';

const arg = (name, fallback) => {
  const i = process.argv.indexOf(name);
  return i !== -1 ? process.argv[i + 1] : fallback;
};
const listPath = arg('--list', join(here, 'instagram-urls.txt'));
const browser = arg('--browser', 'firefox');
const cookiesFile = join(here, 'instagram-cookies.txt');
const outDir = join(here, 'sources', 'instagram');
mkdirSync(outDir, { recursive: true });

if (!existsSync(listPath)) {
  console.error(
    `Liste introuvable : ${listPath}\n` +
      'Créer un fichier texte ou CSV avec une URL de post/reel Instagram par ligne.',
  );
  process.exit(1);
}

// Extraction tolérante : URL instagram.com où qu'elles soient dans la ligne
// (colonnes CSV, guillemets…), normalisées sans query string, dédupliquées.
const urls = [
  ...new Set(
    [...readFileSync(listPath, 'utf8').matchAll(
      /https:\/\/(?:www\.)?instagram\.com\/[^\s",;]+/g,
    )].map((m) => m[0].split('?')[0]),
  ),
];
if (urls.length === 0) {
  console.error(`Aucune URL instagram.com trouvée dans ${listPath}.`);
  process.exit(1);
}
console.log(`${urls.length} URL à récupérer -> ${outDir}`);

// Liste filtrée passée à yt-dlp en un seul appel : les pauses anti-rafale
// s'appliquent entre chaque vidéo, et archive.txt évite les re-téléchargements.
const filtered = join(outDir, 'liste-en-cours.txt');
writeFileSync(filtered, urls.join('\n') + '\n');

const auth = existsSync(cookiesFile)
  ? ['--cookies', cookiesFile]
  : ['--cookies-from-browser', browser];
console.log(
  existsSync(cookiesFile)
    ? `Session : ${cookiesFile}`
    : `Session : cookies du navigateur « ${browser} »`,
);

const r = spawnSync(
  ytdlp,
  [
    ...auth,
    '-a', filtered,
    '-o', join(outDir, '%(uploader_id)s-%(id)s.%(ext)s'),
    '--download-archive', join(outDir, 'archive.txt'),
    '--sleep-interval', '8',
    '--max-sleep-interval', '20',
    '--ignore-errors',
    '--no-overwrites',
    // Correspondance post -> fichier (les carrousels produisent des noms
    // sans le shortcode du post) ; lue par instagram-manifest.mjs.
    '--print-to-file', 'after_move:%(webpage_url)s\t%(filepath)s',
    join(outDir, 'mapping.txt'),
  ],
  { stdio: 'inherit' },
);
if (r.error) {
  console.error(`yt-dlp introuvable (${r.error.message}) — winget install yt-dlp.yt-dlp`);
  process.exit(1);
}

console.log(
  '\nTerminé. Étapes suivantes :\n' +
    ' 1. vérifier les fichiers dans tools/sources/instagram/ ;\n' +
    ' 2. les déclarer dans tools/clips-manifest.json (url = chemin local,\n' +
    '    licence et crédit renseignés — accords écrits conservés hors dépôt) ;\n' +
    ' 3. node tools/prepare-clips.mjs --only <sourceId>.',
);
process.exit(r.status ?? 0);
