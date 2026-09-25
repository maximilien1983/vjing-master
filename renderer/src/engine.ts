import { BeatClock } from './beatClock';
import type { InboundMsg, LevelsMsg, SceneState } from './protocol';

// Résolution interne fixe (brief) : 854 × 480, mise à l'échelle par le CSS.
const INTERNAL_WIDTH = 854;
const INTERNAL_HEIGHT = 480;

const VERTEX_SRC = `#version 300 es
layout(location = 0) in vec2 aPos;
out vec2 vUv;
void main() {
  vUv = aPos * 0.5 + 0.5;
  gl_Position = vec4(aPos, 0.0, 1.0);
}`;

// Jalon 1 : fond génératif « soleil rétrofutur » qui pulse sur le kick.
// uBeat : enveloppe de pulsation (1 à l'attaque du temps, retombe à 0).
// uMeasure : phase de mesure [0,1), rythme les variations lentes.
// uLow/uMid/uHigh : niveaux lissés. uFlash : blanc plein écran. uTime : secondes.
const FRAGMENT_SRC = `#version 300 es
precision highp float;
in vec2 vUv;
out vec4 outColor;
uniform float uTime;
uniform float uBeat;
uniform float uMeasure;
uniform float uLow;
uniform float uMid;
uniform float uHigh;
uniform float uFlash;
uniform vec2 uRes;

void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  float d = length(uv);
  float a = atan(uv.y, uv.x);

  // Soleil central : rayon qui respire avec le kick et les basses.
  float radius = 0.16 + 0.10 * uBeat + 0.06 * uLow;
  float sun = smoothstep(radius + 0.012, radius - 0.012, d);

  // Bandes horizontales du soleil (esthétique rétrofutur).
  float bands = step(0.5, fract(uv.y * 26.0 + uTime * 0.6));
  sun *= mix(1.0, bands, smoothstep(0.0, -0.14, uv.y));

  // Anneaux concentriques qui se propagent depuis le centre sur la mesure.
  float rings = sin(d * 34.0 - uMeasure * 6.2831853 * 4.0) * 0.5 + 0.5;
  rings = pow(rings, 6.0) * smoothstep(0.16, 0.55, d) * (0.25 + 0.75 * uBeat);

  // Grille perspective sous l'horizon, qui défile au tempo.
  float grid = 0.0;
  if (uv.y < -0.08) {
    float py = 1.0 / (abs(uv.y) + 0.02);
    float gx = abs(fract(uv.x * py * 0.35) - 0.5);
    float gy = abs(fract(py * 0.5 - uMeasure * 4.0) - 0.5);
    grid = (smoothstep(0.06, 0.0, gx) + smoothstep(0.08, 0.0, gy))
         * smoothstep(-0.08, -0.5, uv.y) * (0.35 + 0.4 * uMid);
  }

  vec3 magenta = vec3(1.0, 0.15, 0.65);
  vec3 cyan = vec3(0.15, 0.85, 1.0);
  vec3 amber = vec3(1.0, 0.65, 0.25);

  vec3 col = vec3(0.02, 0.01, 0.05);
  col += sun * mix(amber, magenta, clamp(uv.y * 2.0 + 0.6, 0.0, 1.0));
  col += rings * cyan * 0.6;
  col += grid * cyan;
  col += pow(max(0.0, 1.0 - d), 3.0) * magenta * (0.10 + 0.35 * uBeat + 0.2 * uLow);
  col += uHigh * 0.08 * vec3(sin(a * 12.0 + uTime * 3.0) * 0.5 + 0.5);

  col = mix(col, vec3(1.0), clamp(uFlash, 0.0, 1.0));
  outColor = vec4(col, 1.0);
}`;

function compile(gl: WebGL2RenderingContext, type: number, src: string): WebGLShader {
  const shader = gl.createShader(type)!;
  gl.shaderSource(shader, src);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(`Shader: ${gl.getShaderInfoLog(shader)}`);
  }
  return shader;
}

export interface EngineStats {
  fps: number;
  renderMs: number;
  droppedFrames: number;
}

export class Engine {
  private gl: WebGL2RenderingContext;
  private uniforms: Record<string, WebGLUniformLocation | null> = {};
  private clock = new BeatClock();
  private levels = { low: 0, mid: 0, high: 0 };
  private beatEnv = 0;
  private lastBeatIndex = -1;
  private flashArmed = false;
  private flashLevel = 0;
  private startTime = performance.now();
  private lastFrame = performance.now();
  private frameCount = 0;
  private renderMsAccum = 0;
  private dropped = 0;
  private statsWindowStart = performance.now();
  private lastStats: EngineStats = { fps: 0, renderMs: 0, droppedFrames: 0 };
  private running = false;

  constructor(canvas: HTMLCanvasElement) {
    canvas.width = INTERNAL_WIDTH;
    canvas.height = INTERNAL_HEIGHT;
    const gl = canvas.getContext('webgl2', { antialias: false, alpha: false });
    if (!gl) throw new Error('WebGL2 indisponible');
    this.gl = gl;

    const program = gl.createProgram()!;
    gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, VERTEX_SRC));
    gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, FRAGMENT_SRC));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      throw new Error(`Program: ${gl.getProgramInfoLog(program)}`);
    }
    gl.useProgram(program);

    for (const name of ['uTime', 'uBeat', 'uMeasure', 'uLow', 'uMid', 'uHigh', 'uFlash', 'uRes']) {
      this.uniforms[name] = gl.getUniformLocation(program, name);
    }
    gl.uniform2f(this.uniforms.uRes, INTERNAL_WIDTH, INTERNAL_HEIGHT);

    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);
    const buf = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    gl.viewport(0, 0, INTERNAL_WIDTH, INTERNAL_HEIGHT);
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
        }
        break;
      case 'scene':
        this.applyScene(msg.state);
        break;
      case 'config':
      case 'ping':
        break;
    }
  }

  private applyScene(_state: SceneState): void {
    // Jalon 1 : un seul fond shader. Les scènes arrivent au jalon 2.
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

  private frame(onStats?: (s: EngineStats) => void): void {
    const now = performance.now();
    const dt = (now - this.lastFrame) / 1000;
    if (now - this.lastFrame > 50) this.dropped++;
    this.lastFrame = now;

    // Enveloppe de pulsation : saute à 1 à chaque nouveau temps, retombe en ~180 ms,
    // amplifiée par l'énergie des basses au moment de l'attaque.
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
    if (this.flashLevel > 0) {
      const beatDur = this.clock.hasBeat ? 60 / this.clock.currentBpm : 0.15;
      this.flashLevel = Math.max(0, this.flashLevel - dt / beatDur);
    }

    const gl = this.gl;
    const t0 = performance.now();
    gl.uniform1f(this.uniforms.uTime, (now - this.startTime) / 1000);
    gl.uniform1f(this.uniforms.uBeat, this.clock.hasBeat ? this.beatEnv : 0.08 + 0.06 * Math.sin(now / 900));
    const measure = this.clock.measurePhase();
    gl.uniform1f(this.uniforms.uMeasure, measure < 0 ? ((now - this.startTime) / 8000) % 1 : measure);
    gl.uniform1f(this.uniforms.uLow, this.levels.low);
    gl.uniform1f(this.uniforms.uMid, this.levels.mid);
    gl.uniform1f(this.uniforms.uHigh, this.levels.high);
    gl.uniform1f(this.uniforms.uFlash, this.flashLevel);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    this.renderMsAccum += performance.now() - t0;
    this.frameCount++;

    if (now - this.statsWindowStart >= 1000) {
      const windowSec = (now - this.statsWindowStart) / 1000;
      this.lastStats = {
        fps: Math.round((this.frameCount / windowSec) * 10) / 10,
        renderMs: Math.round((this.renderMsAccum / Math.max(1, this.frameCount)) * 100) / 100,
        droppedFrames: this.dropped,
      };
      this.frameCount = 0;
      this.renderMsAccum = 0;
      this.dropped = 0;
      this.statsWindowStart = now;
      onStats?.(this.lastStats);
    }
  }
}
