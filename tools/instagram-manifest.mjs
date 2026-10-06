#!/usr/bin/env node
// Génère tools/clips-manifest.local.json (gitignoré) à partir des vidéos
// de tools/sources/instagram/ : sources locales au schéma de
// clips-manifest.json, fusionnées par prepare-clips.mjs à l'exécution.
//
// Confidentialité (décision 2026-10-06) : rien ne doit permettre de
// retrouver les comptes d'origine dans le dépôt public. D'où des ids
// opaques (cai-/dnc- + hash du nom de fichier, stables d'une exécution à
// l'autre), aucun crédit publié, et ce manifeste local jamais versionné —
// la traçabilité (champ `origine`) reste sur ce poste.
//
// Univers par vidéo, du plus sûr au moins sûr :
//  1. sources/instagram/mapping.txt (écrit par fetch-instagram.mjs) ;
//  2. shortcode du post présent dans le nom de fichier ;
//  3. autre fichier du même compte (préfixe numérique) déjà résolu ;
//  4. défaut : miroir (signalé, à vérifier).
// Les sections de instagram-urls.txt (`# univers: X | epoque: Y`) donnent
// l'univers et l'époque de chaque URL.
//
// Usage : node tools/instagram-manifest.mjs
// Prérequis : ffmpeg (PATH ou FFMPEG=<chemin>) pour mesurer les durées.

import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const ffmpeg = process.env.FFMPEG ?? 'ffmpeg';
const srcDir = join(here, 'sources', 'instagram');
const outPath = join(here, 'clips-manifest.local.json');

const prefixes = { miroir: 'cai', danse: 'dnc' };

// Sections de la liste d'URL -> (url, univers, epoque).
const urlInfo = new Map(); // url sans slash final -> {univers, epoque}
let current = null;
for (const line of readFileSync(join(here, 'instagram-urls.txt'), 'utf8').split('\n')) {
  const section = line.match(/^#\s*univers:\s*([\w-]+)(?:\s*\|\s*epoque:\s*(\S+))?/);
  if (section) {
    current = { univers: section[1], epoque: section[2] ?? '' };
    continue;
  }
  const url = line.match(/https:\/\/(?:www\.)?instagram\.com\/\S+/)?.[0];
  if (url && current) {
    urlInfo.set(url.split('?')[0].replace(/\/$/, ''), current);
  }
}

// mapping.txt : chemin de fichier -> URL du post (runs récents).
const fileToUrl = new Map();
const mappingPath = join(srcDir, 'mapping.txt');
if (existsSync(mappingPath)) {
  for (const line of readFileSync(mappingPath, 'utf8').split('\n')) {
    const [url, file] = line.split('\t');
    if (url && file) fileToUrl.set(basename(file.trim()), url.replace(/\/$/, ''));
  }
}

const shortcodeOf = (url) => url.split('/').filter(Boolean).pop();

function durationOf(file) {
  const r = spawnSync(ffmpeg, ['-i', file, '-f', 'null', '-'], { encoding: 'utf8' });
  const m = (r.stderr ?? '').match(/Duration: (\d+):(\d+):(\d+\.\d+)/);
  if (!m) throw new Error(`durée illisible : ${file}\n${r.stderr?.slice(-500)}`);
  return Math.round(+m[1] * 3600 + +m[2] * 60 + +m[3]);
}

// Extraits de 15 s max (brief : 8-15 s), répartis sur la durée :
// 1 segment par ~20 s de vidéo, 3 au plus, centrés si unique.
function segmentsFor(dur) {
  const len = Math.min(15, dur);
  const n = Math.min(3, Math.max(1, Math.floor(dur / 20)));
  const available = dur - len;
  return Array.from({ length: n }, (_, i) => ({
    start: String(Math.round(n === 1 ? available / 2 : (available * i) / (n - 1))),
    dur: len,
  }));
}

const files = readdirSync(srcDir).filter((f) => f.endsWith('.mp4')).sort();
if (files.length === 0) {
  console.error(`Aucun MP4 dans ${srcDir} — lancer fetch-instagram.mjs d'abord.`);
  process.exit(1);
}

// Passe 1 : univers via mapping.txt ou shortcode dans le nom.
const resolved = new Map(); // fichier -> {info, origine}
for (const f of files) {
  const mapped = fileToUrl.get(f);
  if (mapped && urlInfo.has(mapped)) {
    resolved.set(f, { info: urlInfo.get(mapped), origine: mapped });
    continue;
  }
  for (const [url, info] of urlInfo) {
    if (f.includes(shortcodeOf(url))) {
      resolved.set(f, { info, origine: url });
      break;
    }
  }
}
// Passe 2 : même compte (préfixe numérique) qu'un fichier résolu.
const byAccount = new Map();
for (const [f, r] of resolved) byAccount.set(f.split('-')[0], r.info);
const defauts = [];
for (const f of files) {
  if (resolved.has(f)) continue;
  const sibling = byAccount.get(f.split('-')[0]);
  if (sibling) {
    resolved.set(f, { info: sibling, origine: `même compte qu'un fichier résolu` });
  } else {
    resolved.set(f, { info: { univers: 'miroir', epoque: '2020s' }, origine: 'défaut (à vérifier)' });
    defauts.push(f);
  }
}

const sources = files.map((f) => {
  const { info, origine } = resolved.get(f);
  const file = join(srcDir, f);
  const dur = durationOf(file);
  const id = `${prefixes[info.univers] ?? 'ig'}-${createHash('md5').update(f).digest('hex').slice(0, 6)}`;
  console.log(`${id}  ${info.univers}  ${dur}s  ${f}`);
  return {
    id,
    title: f,
    url: file,
    univers: info.univers,
    epoque: info.epoque,
    source: 'Collection perso (domaine public)',
    licence: 'Domaine public',
    credit: '',
    origine, // trace locale uniquement : jamais recopié dans le catalogue
    segments: segmentsFor(dur),
  };
});

writeFileSync(
  outPath,
  JSON.stringify(
    {
      commentaire:
        'Sources locales (Instagram) générées par instagram-manifest.mjs — gitignoré, ne jamais versionner. Fusionné par prepare-clips.mjs.',
      sources,
    },
    null,
    2,
  ) + '\n',
);
const nSeg = sources.reduce((a, s) => a + s.segments.length, 0);
console.log(`\n${sources.length} sources, ${nSeg} extraits -> ${outPath}`);
if (defauts.length) {
  console.log(`Univers par défaut (miroir) à vérifier : ${defauts.join(', ')}`);
}
