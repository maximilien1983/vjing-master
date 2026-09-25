import { BeatClock } from './beatClock';
import { BACKGROUNDS, COMMON_UNIFORMS, OVERLAYS, POST_FRAGMENT } from './shaders';
import type { InboundMsg, LevelsMsg, SceneState } from './protocol';

// Résolution interne fixe (brief) : 854 × 480, mise à l'échelle par le CSS.
const INTERNAL_WIDTH = 854;
const INTERNAL_HEIGHT = 480;

const FULLSCREEN_VERTEX = `#version 300 es
layout(location = 0) in vec2 aPos;
out vec2 vUv;
void main() {
  vUv = aPos * 0.5 + 0.5;
  gl_Position = vec4(aPos, 0.0, 1.0);
}`;

// Quad transformable des motifs superposés (position, échelle, rotation).
const OVERLAY_VERTEX = `#version 300 es
layout(location = 0) in vec2 aPos;
out vec2 vUv;
uniform vec2 uOffset;
uniform vec2 uScale;
uniform float uRot;
void main() {
  vUv = aPos * 0.5 + 0.5;
  float c = cos(uRot), s = sin(uRot);
  vec2 p = aPos * uScale;
  p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
  gl_Position = vec4(p + uOffset, 0.0, 1.0);
}`;

function assembleFragment(body: string): string {
  return `#version 300 es
precision highp float;
in vec2 vUv;
out vec4 outColor;
${COMMON_UNIFORMS}
uniform float uOpacity;
uniform float uPulse;
${body}`;
}

interface GlProgram {
  program: WebGLProgram;
  uniforms: Map<string, WebGLUniformLocation>;
}

function compile(gl: WebGL2RenderingContext, type: number, src: string): WebGLShader {
  const shader = gl.createShader(type)!;
  gl.shaderSource(shader, src);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(`Shader: ${gl.getShaderInfoLog(shader)}\n${src.slice(0, 400)}`);
  }
  return shader;
}

function link(gl: WebGL2RenderingContext, vs: string, fs: string): GlProgram {
  const program = gl.createProgram()!;
  gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, vs));
  gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, fs));
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(`Program: ${gl.getProgramInfoLog(program)}`);
  }
  const uniforms = new Map<string, WebGLUniformLocation>();
  const count = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS) as number;
  for (let i = 0; i < count; i++) {
    const info = gl.getActiveUniform(program, i)!;
    uniforms.set(info.name, gl.getUniformLocation(program, info.name)!);
  }
  return { program, uniforms };
}

interface OverlaySpec {
  iid: string; // identifiant d'instance, choisi par l'app
  motif: string; // clé dans OVERLAYS
  x: number; // -1..1
  y: number;
  scale: number; // ~0.1..1
  rot: number; // radians
  pulse: number; // 0..1
}

interface OverlayInstance extends OverlaySpec {
  opacity: number;
  fadingOut: boolean;
}

export interface EngineStats {
  fps: number;
  renderMs: number;
  droppedFrames: number;
  bg: string;
}

export class Engine {
  private gl: WebGL2RenderingContext;
  private bgPrograms = new Map<string, GlProgram>();
  private overlayPrograms = new Map<string, GlProgram>();
  private post: GlProgram;
  private fullscreenVao: WebGLVertexArrayObject;
  private quadVao: WebGLVertexArrayObject;
  private sceneTex: WebGLTexture;
  private sceneFbo: WebGLFramebuffer;

  private clock = new BeatClock();
  private levels = { low: 0, mid: 0, high: 0 };
  private light = 0.5;
  private energy = 0.5;

  private currentBg = 'cosmos-sun';
  private nextBg: string | null = null;
  private fadeStart = 0;
  private fadeDurMs = 0;
  private overlays: OverlayInstance[] = [];
  private filters = new Map<string, number>();

  private beatEnv = 0;
  private lastBeatIndex = -1;
  private flashArmed = false;
  private flashLevel = 0;
  private blackLevel = 0;

  private startTime = performance.now();
  private lastFrame = performance.now();
  private frameCount = 0;
  private renderMsAccum = 0;
  private dropped = 0;
  private statsWindowStart = performance.now();
  private lastStats: EngineStats = { fps: 0, renderMs: 0, droppedFrames: 0, bg: this.currentBg };
  private running = false;

  constructor(canvas: HTMLCanvasElement) {
    canvas.width = INTERNAL_WIDTH;
    canvas.height = INTERNAL_HEIGHT;
    const gl = canvas.getContext('webgl2', { antialias: false, alpha: false });
    if (!gl) throw new Error('WebGL2 indisponible');
    this.gl = gl;

    // Triangle plein écran.
    this.fullscreenVao = gl.createVertexArray()!;
    gl.bindVertexArray(this.fullscreenVao);
    const fsBuf = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, fsBuf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

    // Quad des motifs (triangle strip).
    this.quadVao = gl.createVertexArray()!;
    gl.bindVertexArray(this.quadVao);
    const qBuf = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, qBuf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    gl.bindVertexArray(null);

    // Cible de rendu de la scène (avant post-traitement).
    this.sceneTex = gl.createTexture()!;
    gl.bindTexture(gl.TEXTURE_2D, this.sceneTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, INTERNAL_WIDTH, INTERNAL_HEIGHT, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    this.sceneFbo = gl.createFramebuffer()!;
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.sceneFbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.sceneTex, 0);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);

    this.post = link(gl, FULLSCREEN_VERTEX, POST_FRAGMENT);
    gl.viewport(0, 0, INTERNAL_WIDTH, INTERNAL_HEIGHT);
  }

  private bgProgram(id: string): GlProgram {
    let p = this.bgPrograms.get(id);
    if (!p) {
      const body = BACKGROUNDS[id] ?? BACKGROUNDS['cosmos-sun'];
      p = link(this.gl, FULLSCREEN_VERTEX, assembleFragment(body));
      this.bgPrograms.set(id, p);
    }
    return p;
  }

  private overlayProgram(motif: string): GlProgram {
    let p = this.overlayPrograms.get(motif);
    if (!p) {
      const body = OVERLAYS[motif] ?? OVERLAYS['grid'];
      p = link(this.gl, OVERLAY_VERTEX, assembleFragment(body));
      this.overlayPrograms.set(motif, p);
    }
    return p;
  }

  handle(msg: InboundMsg): void {
    switch (msg.type) {
      case 'beat':
        this.clock.update(msg);
        break;
      case 'levels':
        this.smoothLevels(msg);
        break;
      case 'trigger':
        if (msg.id === 'flash') {
          if (this.clock.hasBeat) this.flashArmed = true;
          else this.flashLevel = 1;
        } else if (msg.id === 'drop') {
          this.blackLevel = 1; // coupe au noir ; l'app pousse ensuite énergie et filtres
        }
        break;
      case 'scene':
        this.applyScene(msg.state);
        break;
      case 'config':
        if (msg.energy !== undefined) this.energy = msg.energy;
        if (msg.light !== undefined) this.light = msg.light;
        break;
      case 'ping':
        break;
    }
  }

  private applyScene(state: SceneState): void {
    const bg = state.background;
    if (bg && bg.kind === 'shader' && bg.id !== (this.nextBg ?? this.currentBg)) {
      const beats = state.transition?.beats ?? 4;
      const beatMs = this.clock.hasBeat ? 60000 / this.clock.currentBpm : 500;
      if (state.transition?.kind === 'cut') {
        this.currentBg = bg.id;
        this.nextBg = null;
      } else {
        // Si un fondu est déjà en cours, on le termine net avant d'enchaîner.
        if (this.nextBg) this.currentBg = this.nextBg;
        this.nextBg = bg.id;
        this.fadeStart = performance.now();
        this.fadeDurMs = beats * beatMs;
      }
    }

    // Diff des motifs : nouveaux = fondu d'entrée, absents = fondu de sortie.
    const specs = (state.overlays ?? []) as OverlaySpec[];
    const wanted = new Set(specs.map((s) => s.iid));
    for (const inst of this.overlays) {
      if (!wanted.has(inst.iid)) inst.fadingOut = true;
    }
    for (const spec of specs) {
      const existing = this.overlays.find((o) => o.iid === spec.iid);
      if (existing) {
        Object.assign(existing, spec, { fadingOut: false });
      } else {
        this.overlays.push({ ...spec, opacity: 0, fadingOut: false });
      }
    }

    this.filters.clear();
    for (const f of (state.filters ?? []) as { id: string; intensity: number }[]) {
      this.filters.set(f.id, f.intensity);
    }
  }

  private smoothLevels(msg: LevelsMsg): void {
    const k = 0.5;
    this.levels.low += (msg.low - this.levels.low) * k;
    this.levels.mid += (msg.mid - this.levels.mid) * k;
    this.levels.high += (msg.high - this.levels.high) * k;
  }

  get clockRef(): BeatClock {
    return this.clock;
  }

  get levelsRef(): { low: number; mid: number; high: number } {
    return this.levels;
  }

  get stats(): EngineStats {
    return this.lastStats;
  }

  start(onStats?: (s: EngineStats) => void): void {
    if (this.running) return;
    this.running = true;
    const loop = () => {
      if (!this.running) return;
      this.frame(onStats);
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  private setCommonUniforms(p: GlProgram, now: number): void {
    const gl = this.gl;
    const set1 = (name: string, v: number) => {
      const loc = p.uniforms.get(name);
      if (loc) gl.uniform1f(loc, v);
    };
    set1('uTime', (now - this.startTime) / 1000);
    set1('uBeat', this.clock.hasBeat ? this.beatEnv : 0.08 + 0.06 * Math.sin(now / 900));
    const measure = this.clock.measurePhase();
    set1('uMeasure', measure < 0 ? ((now - this.startTime) / 8000) % 1 : measure);
    set1('uLow', this.levels.low);
    set1('uMid', this.levels.mid);
    set1('uHigh', this.levels.high);
    set1('uLight', this.light);
    set1('uEnergy', this.energy);
    const res = p.uniforms.get('uRes');
    if (res) gl.uniform2f(res, INTERNAL_WIDTH, INTERNAL_HEIGHT);
  }

  private drawBackground(id: string, now: number, fade: number): void {
    const gl = this.gl;
    const p = this.bgProgram(id);
    gl.useProgram(p.program);
    this.setCommonUniforms(p, now);
    gl.bindVertexArray(this.fullscreenVao);
    if (fade < 1) {
      gl.enable(gl.BLEND);
      gl.blendColor(0, 0, 0, fade);
      gl.blendFunc(gl.CONSTANT_ALPHA, gl.ONE_MINUS_CONSTANT_ALPHA);
    } else {
      gl.disable(gl.BLEND);
    }
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.disable(gl.BLEND);
  }

  private frame(onStats?: (s: EngineStats) => void): void {
    const now = performance.now();
    const dt = (now - this.lastFrame) / 1000;
    if (now - this.lastFrame > 50) this.dropped++;
    this.lastFrame = now;
    const beatDurSec = this.clock.hasBeat ? 60 / this.clock.currentBpm : 0.5;

    // Enveloppe de pulsation : 1 à l'attaque du temps, retombe en ~180 ms.
    const beatIndex = this.clock.beatIndex();
    if (beatIndex >= 0 && beatIndex !== this.lastBeatIndex) {
      this.lastBeatIndex = beatIndex;
      this.beatEnv = 0.5 + 0.5 * Math.min(1, this.levels.low * 1.4);
      if (this.flashArmed) {
        this.flashArmed = false;
        this.flashLevel = 1;
      }
    }
    this.beatEnv = Math.max(0, this.beatEnv - dt * 5.5);
    if (this.flashLevel > 0) this.flashLevel = Math.max(0, this.flashLevel - dt / beatDurSec);
    if (this.blackLevel > 0) this.blackLevel = Math.max(0, this.blackLevel - dt / beatDurSec);

    // Fondus des motifs : 1 mesure pour entrer ou sortir.
    const overlayFade = dt / (beatDurSec * 4);
    this.overlays = this.overlays.filter((o) => {
      o.opacity += o.fadingOut ? -overlayFade : overlayFade;
      o.opacity = Math.min(1, Math.max(0, o.opacity));
      return !(o.fadingOut && o.opacity <= 0);
    });

    // Fondu enchaîné du fond.
    let fade = 0;
    if (this.nextBg) {
      fade = (now - this.fadeStart) / this.fadeDurMs;
      if (fade >= 1) {
        this.currentBg = this.nextBg;
        this.nextBg = null;
        fade = 0;
      }
    }

    const gl = this.gl;
    const t0 = performance.now();

    // 1. Scène dans le framebuffer.
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.sceneFbo);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
    this.drawBackground(this.currentBg, now, 1);
    if (this.nextBg) this.drawBackground(this.nextBg, now, fade);

    // 2. Motifs en fusion additive.
    if (this.overlays.length > 0) {
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.ONE, gl.ONE);
      gl.bindVertexArray(this.quadVao);
      const aspect = INTERNAL_WIDTH / INTERNAL_HEIGHT;
      for (const o of this.overlays) {
        const p = this.overlayProgram(o.motif);
        gl.useProgram(p.program);
        this.setCommonUniforms(p, now);
        const set1 = (name: string, v: number) => {
          const loc = p.uniforms.get(name);
          if (loc) gl.uniform1f(loc, v);
        };
        set1('uOpacity', o.opacity);
        set1('uPulse', o.pulse);
        set1('uRot', o.rot);
        const off = p.uniforms.get('uOffset');
        if (off) gl.uniform2f(off, o.x, o.y);
        const sc = p.uniforms.get('uScale');
        if (sc) gl.uniform2f(sc, o.scale / aspect, o.scale);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      }
      gl.disable(gl.BLEND);
    }

    // 3. Post-traitement vers l'écran.
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.useProgram(this.post.program);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.sceneTex);
    const setP = (name: string, v: number) => {
      const loc = this.post.uniforms.get(name);
      if (loc) gl.uniform1f(loc, v);
    };
    gl.uniform1i(this.post.uniforms.get('uScene')!, 0);
    setP('uBloom', this.filters.get('bloom') ?? 0);
    setP('uChroma', this.filters.get('chroma') ?? 0);
    setP('uPosterize', this.filters.get('posterize') ?? 0);
    setP('uHue', this.filters.get('hue') ?? 0);
    setP('uFlash', this.flashLevel);
    setP('uBlack', this.blackLevel);
    const res = this.post.uniforms.get('uRes');
    if (res) gl.uniform2f(res, INTERNAL_WIDTH, INTERNAL_HEIGHT);
    gl.bindVertexArray(this.fullscreenVao);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    this.renderMsAccum += performance.now() - t0;
    this.frameCount++;

    if (now - this.statsWindowStart >= 1000) {
      const windowSec = (now - this.statsWindowStart) / 1000;
      this.lastStats = {
        fps: Math.round((this.frameCount / windowSec) * 10) / 10,
        renderMs: Math.round((this.renderMsAccum / Math.max(1, this.frameCount)) * 100) / 100,
        droppedFrames: this.dropped,
        bg: this.currentBg,
      };
      this.frameCount = 0;
      this.renderMsAccum = 0;
      this.dropped = 0;
      this.statsWindowStart = now;
      onStats?.(this.lastStats);
    }
  }
}
