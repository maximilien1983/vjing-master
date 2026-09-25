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

const engine = new Engine(canvas);
let debug = false;

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
    if (msg.type === 'config' && msg.debug !== undefined) {
      debug = msg.debug;
      debugEl.style.display = debug ? 'block' : 'none';
    }
    if (msg.type === 'ping') {
      sendFeedback({ type: 'pong', t: msg.t, tr: Date.now() });
      return;
    }
    engine.handle(msg);
  },
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
    `${stats.fps} i/s  ${stats.renderMs} ms  perdu ${stats.droppedFrames}`;
});

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
