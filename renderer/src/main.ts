import { Engine } from './engine';
import type { InboundMsg, OutboundMsg } from './protocol';

declare global {
  interface Window {
    VJM: {
      handleMessage: (msg: InboundMsg | string) => void;
      onFeedback: ((msg: OutboundMsg) => void) | null;
    };
    // JS channel injecté par la WebView Flutter (webview_flutter).
    VjmFeedback?: { postMessage: (s: string) => void };
  }
}

const canvas = document.getElementById('vjm-canvas') as HTMLCanvasElement;
const debugEl = document.getElementById('vjm-debug') as HTMLDivElement;
const beatBarEl = document.getElementById('vjm-beatbar') as HTMLDivElement;

const engine = new Engine(canvas);
let debug = false;
let beatBar = false;

// Jauge de calibration (gauche de l'écran) : pleine à l'attaque de chaque
// temps EXTRAPOLÉ par le moteur (décalage SYNC inclus), se vide jusqu'au
// temps suivant. Le sommet doit claquer pile sur le kick audible.
function beatBarLoop(): void {
  if (beatBar) {
    const phase = engine.clockRef.beatPhase();
    if (phase < 0) {
      beatBarEl.style.height = '0';
    } else {
      const fill = 1 - phase;
      beatBarEl.style.height = `${(fill * 100).toFixed(1)}%`;
      // Plus vive à l'attaque, glow renforcé sur le temps 1.
      const attack = phase < 0.12;
      beatBarEl.style.filter = attack ? 'brightness(1.5)' : 'none';
      beatBarEl.style.boxShadow =
        attack && engine.clockRef.beatIndex() === 0
          ? '0 0 26px rgba(255, 60, 30, .95)'
          : '0 0 12px rgba(255, 40, 20, .6)';
    }
  }
  requestAnimationFrame(beatBarLoop);
}
requestAnimationFrame(beatBarLoop);

function sendFeedback(msg: OutboundMsg): void {
  window.VJM.onFeedback?.(msg);
  window.VjmFeedback?.postMessage(JSON.stringify(msg));
  // Enveloppe iframe (préviz Flutter web) : feedback vers la page parente.
  if (window.parent && window.parent !== window) {
    window.parent.postMessage(JSON.stringify(msg), '*');
  }
}

// Enveloppe iframe : messages entrants par postMessage (chaînes JSON).
window.addEventListener('message', (e) => {
  if (typeof e.data === 'string' && e.data.startsWith('{')) {
    window.VJM.handleMessage(e.data);
  }
});

window.VJM = {
  onFeedback: null,
  handleMessage(raw: InboundMsg | string): void {
    let msg: InboundMsg;
    try {
      msg = typeof raw === 'string' ? (JSON.parse(raw) as InboundMsg) : raw;
    } catch (e) {
      console.error('VJM: message illisible', raw, e);
      return;
    }
    if (msg.type === 'config') {
      if (msg.debug !== undefined) {
        debug = msg.debug;
        debugEl.style.display = debug ? 'block' : 'none';
      }
      if (msg.beatBar !== undefined) {
        beatBar = msg.beatBar;
        beatBarEl.style.display = beatBar ? 'block' : 'none';
        if (!beatBar) beatBarEl.style.height = '0';
      }
    }
    if (msg.type === 'ping') {
      sendFeedback({ type: 'pong', t: msg.t, tr: Date.now() });
      return;
    }
    engine.handle(msg);
  },
};

// Clip illisible : l'app le bannit et pousse une autre scène.
engine.onBgError = (id, reason) => {
  sendFeedback({ type: 'bgerror', id, reason });
};

engine.start((stats) => {
  if (!debug) return;
  sendFeedback({ ...stats, type: 'stats', t: Date.now() });
  const clock = engine.clockRef;
  const lv = engine.levelsRef;
  debugEl.textContent =
    `BPM    ${clock.hasBeat ? clock.currentBpm.toFixed(1) : '—'}\n` +
    `mesure ${clock.hasBeat ? clock.measurePhase().toFixed(2) : '—'}  temps ${clock.hasBeat ? clock.beatIndex() + 1 : '—'}\n` +
    `L ${lv.low.toFixed(2)}  M ${lv.mid.toFixed(2)}  H ${lv.high.toFixed(2)}\n` +
    `fond ${stats.bg}\n` +
    `${stats.fps} i/s  ${stats.renderMs} ms  perdu ${stats.droppedFrames}`;
});

// Test visuel direct, utilisé par les captures automatisées et le dev :
//   ?bg=cosmos-stars                    force un fond
//   ?motifs=grid,loop                   ajoute des motifs (positions fixes)
//   ?filters=bloom:0.7,chroma:0.6       applique des filtres
//   ?demo=1                             raccourci Retrofutur complet
// Toute erreur (shader compris) remonte dans le titre de la page.
{
  window.addEventListener('error', (e) => {
    document.title = `VJM-ERROR ${e.message}`;
    // Visible aussi dans les captures automatisées.
    debugEl.style.display = 'block';
    debugEl.style.color = '#ff5040';
    debugEl.textContent = `ERREUR : ${e.message}`;
  });
  const params = new URLSearchParams(location.search);
  const bg = params.get('bg');
  const video = params.get('video'); // URL d'un clip : fond kind "video"
  const demo = params.get('demo');
  const motifs = (params.get('motifs') ?? (demo ? 'grid,loop' : ''))
    .split(',')
    .filter(Boolean);
  const filters = (params.get('filters') ?? (demo ? 'bloom:0.7,chroma:0.6' : ''))
    .split(',')
    .filter(Boolean)
    .map((s) => {
      const [id, i] = s.split(':');
      return { id, intensity: i ? parseFloat(i) : 0.8 };
    });
  const slots = [
    { x: -0.5, y: 0.3, scale: 0.5, rot: 0.4 },
    { x: 0.55, y: -0.25, scale: 0.45, rot: 0 },
    { x: 0.1, y: 0.1, scale: 0.6, rot: -0.3 },
  ];
  if (bg || video || demo || motifs.length || filters.length) {
    window.VJM.handleMessage({
      type: 'scene',
      state: {
        background: video
          ? { kind: 'video', id: 'test-video', url: video }
          : { kind: 'shader', id: bg ?? 'cosmos-sun' },
        overlays: motifs.map((motif, i) => ({
          iid: `t${i}`,
          motif,
          ...slots[i % slots.length],
          pulse: 0.8,
        })),
        filters,
        transition: { kind: 'cut', beats: 0 },
      },
    });
    window.VJM.handleMessage({ type: 'levels', low: 0.8, mid: 0.5, high: 0.4 });
  }
}

// Dev navigateur : simulation clavier (d = debug, f = flash, b = beat 124 BPM).
if (import.meta.env.DEV) {
  let simBpm = 0;
  window.addEventListener('keydown', (e) => {
    if (e.key === 'd') window.VJM.handleMessage({ type: 'config', debug: !debug });
    if (e.key === 'f') window.VJM.handleMessage({ type: 'trigger', id: 'flash' });
    if (e.key === 'b') {
      simBpm = simBpm ? 0 : 124;
      window.VJM.handleMessage({ type: 'beat', bpm: simBpm, phase: 0, t0: Date.now(), offsetMs: 0 });
    }
  });
  setInterval(() => {
    if (!simBpm) return;
    const beatDur = 60000 / simBpm;
    const phase = ((Date.now() % (beatDur * 4)) / (beatDur * 4) + 0.02) % 1;
    const kick = phase * 4 % 1 < 0.15 ? 0.9 : 0.2;
    window.VJM.handleMessage({ type: 'levels', low: kick, mid: 0.3 + 0.2 * Math.sin(Date.now() / 700), high: 0.25 });
  }, 80);
}
