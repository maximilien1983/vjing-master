// Bibliothèque GLSL du jalon 2 : fonds Cosmos et motifs superposés.
// Tous les fonds partagent les mêmes uniforms (voir engine.ts) ; les motifs
// reçoivent en plus uOpacity et uPulse et rendent sur fond noir (fusion
// additive, pas de canal alpha — conforme au brief).

export const COMMON_UNIFORMS = `
uniform float uTime;
uniform float uBeat;
uniform float uMeasure;
uniform float uLow;
uniform float uMid;
uniform float uHigh;
uniform float uLight;   // 0 dark .. 1 lumineux
uniform float uEnergy;  // 0 .. 1
uniform vec2 uRes;
`;

const NOISE = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
             mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
  return v;
}
`;

// --- Fonds -----------------------------------------------------------------

// Soleil rétrofutur à bandes + grille en perspective (fond du jalon 1).
const BG_SUN = `
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  float d = length(uv);
  float radius = 0.16 + 0.10 * uBeat + 0.06 * uLow;
  float sun = smoothstep(radius + 0.012, radius - 0.012, d);
  float bands = step(0.5, fract(uv.y * 26.0 + uTime * 0.6));
  sun *= mix(1.0, bands, smoothstep(0.0, -0.14, uv.y));
  float rings = sin(d * 34.0 - uMeasure * 25.13) * 0.5 + 0.5;
  rings = pow(rings, 6.0) * smoothstep(0.16, 0.55, d) * (0.25 + 0.75 * uBeat);
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
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Champ d'étoiles en parallaxe, scintillement sur les aigus, pulsation douce.
const BG_STARS = `
${NOISE}
vec3 starLayer(vec2 uv, float scale, float speed, float brightness) {
  vec2 p = uv * scale + vec2(uTime * speed * 0.02, uMeasure * speed * 0.05);
  vec2 cell = floor(p);
  vec2 f = fract(p) - 0.5;
  float h = hash(cell);
  vec2 offset = vec2(hash(cell + 7.0), hash(cell + 13.0)) - 0.5;
  float d = length(f - offset * 0.7);
  float twinkle = 0.7 + 0.3 * sin(uTime * (2.0 + h * 6.0) + h * 40.0) * (0.4 + 0.6 * uHigh);
  float star = smoothstep(0.06 + h * 0.05, 0.0, d) * step(0.72, h) * twinkle;
  vec3 tint = mix(vec3(0.6, 0.8, 1.0), vec3(1.0, 0.5, 0.8), h);
  return star * brightness * tint;
}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = mix(vec3(0.01, 0.0, 0.04), vec3(0.03, 0.02, 0.10), vUv.y);
  col += starLayer(uv, 14.0, 1.0, 0.9);
  col += starLayer(uv, 26.0, 2.2, 0.55);
  col += starLayer(uv, 44.0, 4.0, 0.35);
  // Voie lactée diagonale discrète qui respire avec les basses.
  float band = exp(-pow((uv.y - uv.x * 0.3) * 3.0, 2.0));
  col += band * vec3(0.10, 0.07, 0.16) * (0.5 + 0.5 * uLow + 0.4 * uBeat);
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Nébuleuse fbm magenta/cyan, lente dérive, pulse sur le kick.
const BG_NEBULA = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec2 drift = vec2(uTime * 0.015, uMeasure * 0.08);
  float n1 = fbm(uv * 2.2 + drift);
  float n2 = fbm(uv * 3.6 - drift * 1.4 + n1 * 1.2);
  float n3 = fbm(uv * 1.4 + vec2(n2, n1) * (0.8 + 0.5 * uBeat));
  vec3 magenta = vec3(0.85, 0.12, 0.55);
  vec3 cyan = vec3(0.10, 0.65, 0.90);
  vec3 deep = vec3(0.03, 0.01, 0.08);
  vec3 col = deep;
  col += magenta * pow(n2, 2.2) * (0.9 + 0.6 * uLow + 0.5 * uBeat);
  col += cyan * pow(n3, 2.6) * (0.8 + 0.5 * uMid);
  col += vec3(1.0, 0.9, 0.8) * pow(n1 * n3, 5.0) * 1.4;
  col *= 0.5 + 1.0 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Tunnel d'anneaux néon, avance calée sur la mesure, kick = accélération.
const BG_RINGS = `
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  float d = length(uv) + 0.0001;
  float a = atan(uv.y, uv.x);
  float depth = 0.35 / d - uMeasure * 3.0;
  float ring = abs(fract(depth) - 0.5);
  float glow = smoothstep(0.22, 0.0, ring) * (0.35 + 0.65 * uBeat);
  float seg = 0.75 + 0.25 * sin(a * 8.0 + uTime * 0.7);
  float idx = mod(floor(depth), 2.0);
  vec3 c1 = vec3(1.0, 0.15, 0.65);
  vec3 c2 = vec3(0.15, 0.85, 1.0);
  vec3 col = mix(c1, c2, idx) * glow * seg;
  col *= smoothstep(1.4, 0.25, d); // fond du tunnel sombre
  col += vec3(1.0, 0.8, 0.9) * smoothstep(0.05, 0.0, d) * uBeat * 0.6;
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

export const BACKGROUNDS: Record<string, string> = {
  'cosmos-sun': BG_SUN,
  'cosmos-stars': BG_STARS,
  'cosmos-nebula': BG_NEBULA,
  'cosmos-rings': BG_RINGS,
};

// --- Motifs superposés (rendus sur noir, fusion additive) ------------------
// Uniforms additionnels : uOpacity (fondu), uPulse (0..1, force de pulsation).

// Grille néon inclinée.
const OV_GRID = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float pulse = 1.0 + uPulse * uBeat * 0.5;
  vec2 g = abs(fract(uv * 3.0 * pulse) - 0.5);
  float line = smoothstep(0.06, 0.0, min(g.x, g.y));
  float mask = smoothstep(1.3, 0.4, length(uv));
  vec3 col = vec3(0.15, 0.85, 1.0) * line * mask * (0.5 + 0.5 * uMid);
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Petit soleil / halo à bandes.
const OV_SUN = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float d = length(uv);
  float radius = 0.5 + uPulse * uBeat * 0.18;
  float disc = smoothstep(radius, radius - 0.05, d);
  float bands = step(0.45, fract(uv.y * 9.0 - uTime * 0.4));
  disc *= mix(1.0, bands, smoothstep(0.1, -0.2, uv.y));
  float halo = pow(max(0.0, 1.0 - d), 2.5) * 0.6;
  vec3 col = vec3(1.0, 0.55, 0.20) * disc + vec3(1.0, 0.3, 0.5) * halo;
  outColor = vec4(col * uOpacity * (0.6 + 0.4 * uLow), 1.0);
}`;

// Boucle néon (lissajous) qui tourne, épaisseur pulsée.
const OV_LOOP = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float t = uTime * 0.3 + uMeasure * 6.2831;
  float best = 1e3;
  for (int i = 0; i < 90; i++) {
    float s = float(i) / 90.0 * 6.2831;
    vec2 p = vec2(sin(s * 2.0 + t), sin(s * 3.0 + t * 0.7)) * 0.55;
    best = min(best, length(uv - p));
  }
  float w = 0.035 + uPulse * uBeat * 0.03;
  float line = smoothstep(w, w * 0.3, best);
  vec3 col = mix(vec3(1.0, 0.15, 0.65), vec3(0.15, 0.85, 1.0), sin(t) * 0.5 + 0.5);
  outColor = vec4(col * line * uOpacity * (0.6 + 0.4 * uHigh), 1.0);
}`;

export const OVERLAYS: Record<string, string> = {
  'grid': OV_GRID,
  'sun': OV_SUN,
  'loop': OV_LOOP,
};

// --- Post-traitement -------------------------------------------------------
// Chaîne unique paramétrée : chaque filtre a une intensité 0..1 (0 = inactif).
// Suffisant pour Retrofutur (bloom + décalage chromatique) ; extensible.

export const POST_FRAGMENT = `#version 300 es
precision highp float;
in vec2 vUv;
out vec4 outColor;
uniform sampler2D uScene;
uniform float uBloom;
uniform float uChroma;
uniform float uPosterize;
uniform float uHue;
uniform float uFlash;
uniform float uBlack;
uniform vec2 uRes;

vec3 hueShift(vec3 c, float a) {
  const vec3 k = vec3(0.57735);
  return c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cos(a));
}

void main() {
  vec2 px = 1.0 / uRes;
  // Décalage chromatique radial.
  vec2 dir = (vUv - 0.5) * uChroma * 0.02;
  vec3 col;
  col.r = texture(uScene, vUv + dir).r;
  col.g = texture(uScene, vUv).g;
  col.b = texture(uScene, vUv - dir).b;
  // Bloom approché : moyenne élargie des voisins brillants.
  if (uBloom > 0.001) {
    vec3 acc = vec3(0.0);
    for (int x = -2; x <= 2; x++)
      for (int y = -2; y <= 2; y++)
        acc += texture(uScene, vUv + vec2(float(x), float(y)) * px * 2.5).rgb;
    acc /= 25.0;
    col += max(acc - 0.35, 0.0) * uBloom * 1.6;
  }
  if (uPosterize > 0.001) {
    float levels = mix(24.0, 4.0, uPosterize);
    col = floor(col * levels) / levels;
  }
  if (abs(uHue) > 0.001) col = hueShift(col, uHue);
  col = mix(col, vec3(0.0), clamp(uBlack, 0.0, 1.0));
  col = mix(col, vec3(1.0), clamp(uFlash, 0.0, 1.0));
  outColor = vec4(col, 1.0);
}`;
