#!/usr/bin/env node
// Pipeline de préparation des clips (brief : /tools).
//
// Lit tools/clips-manifest.json, découpe chaque segment (ffmpeg accepte les
// URL http(s) : seules les plages nécessaires sont téléchargées), normalise
// (854 px de large, muet, h264 faststart), mesure la luminosité moyenne
// (signalstats YAVG) et la couleur dominante (image réduite à 1×1), puis
// écrit catalog/clips.json (schéma du brief : url, durée, tags, source,
// licence, crédit).
//
// Usage : node tools/prepare-clips.mjs [--only <sourceId>]
// Prérequis : ffmpeg dans le PATH ou FFMPEG=<chemin>.

import { execFileSync, spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const ffmpeg = process.env.FFMPEG ?? 'ffmpeg';
const manifest = JSON.parse(readFileSync(join(here, 'clips-manifest.json'), 'utf8'));
const outDir = resolve(here, manifest.output);
const catalogPath = resolve(here, manifest.catalog);
mkdirSync(outDir, { recursive: true });

const only = process.argv.includes('--only')
  ? process.argv[process.argv.indexOf('--only') + 1]
  : null;

function run(args, opts = {}) {
  const r = spawnSync(ffmpeg, args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...opts });
  if (r.status !== 0) {
    throw new Error(`ffmpeg ${args.join(' ')}\n${r.stderr?.slice(-2000)}`);
  }
  return r;
}

/// Luminosité moyenne 0..1 : moyenne des YAVG de signalstats (1 image / s).
function luminosity(file) {
  const r = spawnSync(
    ffmpeg,
    ['-i', file, '-vf', 'fps=1,signalstats,metadata=print:key=lavfi.signalstats.YAVG', '-f', 'null', '-'],
    { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
  );
  const values = [...(r.stderr + r.stdout).matchAll(/YAVG=([0-9.]+)/g)].map((m) => parseFloat(m[1]));
  if (values.length === 0) return 0.5;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length / 255) * 100) / 100;
}

/// Couleur dominante : frame médiane réduite à 1×1 px, en hex.
function dominantColor(file, midSec) {
  const r = run([
    '-ss', String(midSec), '-i', file,
    '-frames:v', '1', '-vf', 'scale=1:1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-',
  ], { encoding: 'buffer' });
  const [rr, gg, bb] = r.stdout;
  return `#${[rr, gg, bb].map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

function durationOf(file) {
  const r = spawnSync(ffmpeg, ['-i', file, '-f', 'null', '-'], { encoding: 'utf8' });
  const m = (r.stderr ?? '').match(/Duration: (\d+):(\d+):(\d+\.\d+)/);
  if (!m) return 0;
  return Math.round(+m[1] * 3600 + +m[2] * 60 + +m[3]);
}

const entries = [];
for (const src of manifest.sources) {
  if (only && src.id !== only) continue;
  console.log(`\n== ${src.id} : ${src.title}`);
  src.segments.forEach((seg, i) => {
    const name = `${src.id}-${String(i + 1).padStart(2, '0')}.mp4`;
    const out = join(outDir, name);
    if (!existsSync(out) || process.argv.includes('--force')) {
      console.log(`   découpe ${seg.start} +${seg.dur}s -> ${name}`);
      run([
        '-y',
        '-ss', seg.start,
        '-i', src.url,
        '-t', String(seg.dur),
        '-vf', 'scale=854:-2',
        '-an',
        '-c:v', 'libx264', '-crf', '26', '-preset', 'veryfast',
        '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
        out,
      ]);
    } else {
      console.log(`   déjà présent : ${name}`);
    }
    const dur = durationOf(out) || seg.dur;
    const lum = luminosity(out);
    const col = dominantColor(out, Math.floor(dur / 2));
    // Vignette de l'extrait (aperçus de la console).
    const thumbName = `${src.id}-${String(i + 1).padStart(2, '0')}.jpg`;
    const thumb = join(outDir, thumbName);
    if (!existsSync(thumb) || process.argv.includes('--force')) {
      run(['-y', '-ss', String(Math.floor(dur / 2)), '-i', out,
        '-frames:v', '1', '-vf', 'scale=320:-2', '-q:v', '5', thumb]);
    }
    console.log(`   luminosité ${lum}  couleur ${col}  durée ${dur}s`);
    entries.push({
      id: `${src.id}-${String(i + 1).padStart(2, '0')}`,
      url: `${manifest.baseUrl}${name}`,
      vignette: `${manifest.baseUrl}${thumbName}`,
      duree: dur,
      tags: {
        univers: src.univers,
        epoque: src.epoque,
        luminosite: lum,
        couleur: col,
        ...(seg.tags ? { extra: seg.tags } : {}),
      },
      source: src.source,
      licence: src.licence,
      credit: src.credit,
    });
  });
}

// Fusion avec le catalogue existant (--only ne doit pas écraser le reste).
let existing = [];
if (existsSync(catalogPath)) {
  existing = JSON.parse(readFileSync(catalogPath, 'utf8')).clips ?? [];
}
const replacedIds = new Set(entries.map((e) => e.id));
const merged = [...existing.filter((e) => !replacedIds.has(e.id)), ...entries];
merged.sort((a, b) => a.id.localeCompare(b.id));
writeFileSync(
  catalogPath,
  JSON.stringify(
    {
      version: 1,
      commentaire:
        'Catalogue de clips généré par tools/prepare-clips.mjs — ne pas éditer à la main. Schéma : brief « Tagging et catalogue ».',
      clips: merged,
    },
    null,
    2,
  ) + '\n',
);
console.log(`\nCatalogue : ${merged.length} clips -> ${catalogPath}`);
console.log('Validation manuelle des tags avant commit (décision produit).');
