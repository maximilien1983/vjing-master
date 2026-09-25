import type { BeatMsg } from './protocol';

// Extrapole la phase de mesure entre deux messages `beat`.
// L'horloge de l'émetteur (t0, epoch ms) peut dériver de la nôtre : on mesure
// l'écart Date.now() - t0 à la réception et on le lisse pour absorber la gigue
// de transport (WebView ~0 ms, Chromecast variable).
export class BeatClock {
  private bpm = 0;
  private phaseAtT0 = 0;
  private t0 = 0;
  private offsetMs = 0;
  private clockSkewMs = 0;
  private hasSkew = false;

  update(msg: BeatMsg): void {
    const skew = Date.now() - msg.t0;
    if (!this.hasSkew || msg.bpm !== this.bpm) {
      this.clockSkewMs = skew;
      this.hasSkew = true;
    } else {
      this.clockSkewMs += (skew - this.clockSkewMs) * 0.1;
    }
    this.bpm = msg.bpm;
    this.phaseAtT0 = msg.phase;
    this.t0 = msg.t0;
    this.offsetMs = msg.offsetMs;
  }

  get hasBeat(): boolean {
    return this.bpm > 0;
  }

  get currentBpm(): number {
    return this.bpm;
  }

  // Position dans la mesure de 4 temps, [0, 1). Sans beat : -1.
  measurePhase(nowMs: number = Date.now()): number {
    if (this.bpm <= 0) return -1;
    const senderNow = nowMs - this.clockSkewMs;
    const elapsed = senderNow - this.t0 - this.offsetMs;
    const measures = (elapsed / 60000) * (this.bpm / 4);
    const phase = (this.phaseAtT0 + measures) % 1;
    return phase < 0 ? phase + 1 : phase;
  }

  // Position dans le temps courant, [0, 1). 0 = attaque du temps.
  beatPhase(nowMs: number = Date.now()): number {
    const m = this.measurePhase(nowMs);
    return m < 0 ? -1 : (m * 4) % 1;
  }

  // Index du temps dans la mesure : 0 à 3.
  beatIndex(nowMs: number = Date.now()): number {
    const m = this.measurePhase(nowMs);
    return m < 0 ? -1 : Math.floor(m * 4) % 4;
  }
}
