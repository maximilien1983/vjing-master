// Bibliothèque GLSL : fonds par univers, motifs par style, post-traitement.
// Tous les fonds partagent les mêmes uniforms (voir engine.ts) ; les motifs
// reçoivent en plus uOpacity et uPulse et rendent sur fond noir (fusion
// additive, pas de canal alpha — conforme au brief).
// Jalon 4 : fonds shaders des 6 univers (Miroir : placeholders en attendant
// la caméra du jalon 5) et motifs des 6 styles (brief « Paramètres »).

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

// --- Fonds : Cosmos ----------------------------------------------------------

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

// --- Fonds : Campagne --------------------------------------------------------

// Collines en couches au crépuscule, soleil bas, brume qui respire.
const BG_COLLINES = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 skyHi = mix(vec3(0.10, 0.06, 0.16), vec3(0.55, 0.55, 0.75), uLight);
  vec3 skyLo = mix(vec3(0.55, 0.22, 0.12), vec3(1.0, 0.72, 0.40), uLight);
  vec3 col = mix(skyLo, skyHi, clamp(uv.y * 1.6 + 0.5, 0.0, 1.0));
  // Soleil bas qui pulse doucement sur le kick.
  vec2 sunP = uv - vec2(0.22, -0.02);
  float sd = length(sunP);
  col += vec3(1.0, 0.62, 0.28) * smoothstep(0.10 + 0.02 * uBeat, 0.02, sd) * 1.1;
  col += vec3(1.0, 0.5, 0.2) * pow(max(0.0, 1.0 - sd), 4.0) * (0.3 + 0.3 * uBeat);
  // Trois plans de collines : silhouettes en bruit basse fréquence.
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float h = -0.08 - fi * 0.12
            + noise(vec2(uv.x * (1.4 + fi * 0.8) + fi * 9.0 + uMeasure * 0.05 * (1.0 + fi), fi)) * 0.16;
    float m = smoothstep(h + 0.006, h - 0.006, uv.y);
    vec3 hill = mix(vec3(0.16, 0.13, 0.10), vec3(0.05, 0.06, 0.04), fi / 2.0);
    hill *= 0.5 + 0.9 * uLight;
    col = mix(col, hill, m * (0.75 + fi * 0.12));
  }
  // Brume au ras du sol qui respire avec les basses.
  float mist = exp(-pow((uv.y + 0.30) * 5.0, 2.0)) * fbm(uv * 3.0 + vec2(uTime * 0.03, 0.0));
  col += mist * vec3(0.5, 0.4, 0.35) * (0.15 + 0.25 * uLow);
  col *= 0.6 + 0.8 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Champ de blé : tiges dorées ondulant au vent, vent calé sur la mesure.
const BG_BLE = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  // Ciel de fin d'après-midi avec soleil bas et quelques nuages étirés.
  vec3 sky = mix(vec3(0.45, 0.30, 0.14), vec3(0.80, 0.72, 0.52), uLight);
  vec3 col = mix(sky * 0.55, sky, clamp(uv.y * 1.6 + 0.3, 0.0, 1.0));
  float sd = length(uv - vec2(-0.28, 0.16));
  col += vec3(1.0, 0.75, 0.35) * smoothstep(0.09 + 0.02 * uBeat, 0.02, sd);
  col += vec3(1.0, 0.6, 0.25) * pow(max(0.0, 1.0 - sd), 4.0) * 0.35;
  float wisp = fbm(vec2(uv.x * 2.0 + uTime * 0.02, uv.y * 8.0));
  col += vec3(0.9, 0.75, 0.55) * smoothstep(0.55, 0.8, wisp) * step(0.05, uv.y) * 0.25;
  float horizon = -0.02;
  if (uv.y < horizon) {
    // Profondeur du champ : plus près = tiges plus larges et plus sombres.
    float depth = (horizon - uv.y) / (horizon + 0.5);
    float wind = sin(uMeasure * 6.2831 + uv.x * 2.0) * (0.3 + 0.4 * uLow) + uTime * 0.05;
    float x = uv.x * mix(60.0, 14.0, depth) + wind * depth * 4.0;
    float stalk = abs(fract(x + noise(vec2(floor(x), 3.0))) - 0.5);
    float body = smoothstep(0.32, 0.05, stalk);
    vec3 gold = mix(vec3(0.75, 0.55, 0.16), vec3(0.95, 0.78, 0.30), noise(vec2(floor(x) * 0.37, 1.0)));
    vec3 field = gold * (0.35 + 0.65 * (1.0 - depth)) * body
               + vec3(0.30, 0.20, 0.06) * (1.0 - body);
    col = mix(col, field, smoothstep(horizon + 0.01, horizon - 0.03, uv.y));
    // Vague de lumière qui traverse le champ sur le kick.
    float wave = exp(-pow((fract(uMeasure) * 2.4 - 1.2 - uv.x) * 3.0, 2.0));
    col += wave * vec3(0.5, 0.38, 0.12) * uBeat * (1.0 - depth) * 0.6;
  }
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Ciel de nuages fbm, dérive lente, éclaircies sur les mediums.
const BG_NUAGES = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 skyTop = mix(vec3(0.06, 0.10, 0.22), vec3(0.30, 0.55, 0.85), uLight);
  vec3 skyBot = mix(vec3(0.16, 0.12, 0.20), vec3(0.75, 0.80, 0.90), uLight);
  vec3 col = mix(skyBot, skyTop, clamp(uv.y + 0.5, 0.0, 1.0));
  vec2 drift = vec2(uTime * 0.02 + uMeasure * 0.05, 0.0);
  float c1 = fbm(uv * vec2(1.6, 3.2) + drift);
  float c2 = fbm(uv * vec2(2.8, 5.0) - drift * 1.7 + 4.0);
  float cloud = smoothstep(0.42, 0.72, c1 * 0.65 + c2 * 0.45);
  vec3 cloudCol = mix(vec3(0.55, 0.50, 0.55), vec3(1.0, 0.98, 0.94), uLight)
                * (0.8 + 0.3 * c2 + 0.15 * uMid);
  vec3 shade = cloudCol * 0.45;
  col = mix(col, mix(shade, cloudCol, smoothstep(0.3, 0.9, c1)), cloud);
  // Percée de lumière qui pulse doucement.
  col += vec3(1.0, 0.9, 0.7) * pow(max(0.0, 1.0 - length(uv - vec2(-0.3, 0.25))), 3.0)
       * (0.08 + 0.20 * uBeat) * uLight;
  col *= 0.5 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// --- Fonds : Danse -----------------------------------------------------------

// Projecteurs de scène : faisceaux colorés qui balaient sur la mesure,
// brume, sol luisant. La foule est dans les clips ; ici c'est la lumière.
const BG_SPOTS = `
${NOISE}
float beam(vec2 uv, vec2 origin, float angle, float width) {
  vec2 d = uv - origin;
  float along = -d.y;
  float across = d.x - d.y * tan(angle);
  return smoothstep(width * (0.3 + along), 0.0, abs(across)) * step(0.0, along);
}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = vec3(0.015, 0.01, 0.03);
  vec3 tints[4] = vec3[4](
    vec3(1.0, 0.20, 0.55), vec3(0.20, 0.70, 1.0),
    vec3(1.0, 0.65, 0.15), vec3(0.55, 0.30, 1.0));
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    float sweep = sin(uMeasure * 6.2831 * (0.5 + fi * 0.13) + fi * 2.1) * 0.55;
    vec2 origin = vec2(-0.66 + fi * 0.44, 0.62);
    float b = beam(uv, origin, sweep, 0.05 + 0.02 * fi);
    col += tints[i] * b * (0.28 + 0.5 * uBeat) * smoothstep(0.62, -0.35, uv.y);
  }
  // Brume qui accroche la lumière.
  col += vec3(0.5, 0.45, 0.6) * fbm(uv * 3.0 + vec2(uTime * 0.05, 0.0)) * 0.08;
  // Sol luisant : reflet des faisceaux.
  if (uv.y < -0.32) {
    col += vec3(0.25, 0.2, 0.35) * (0.3 + 0.7 * uBeat) * exp((uv.y + 0.32) * 6.0) * 0.5;
  }
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Boule à facettes : sphère scintillante, taches de lumière qui tournent.
const BG_DISCO = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = vec3(0.02, 0.015, 0.04);
  // Taches de lumière sur les murs : grille de points qui tourne.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    vec2 p = uv * (5.0 + fl * 3.0);
    p.x += uMeasure * (2.0 + fl) + fl * 7.0;
    p.y += sin(uMeasure * 3.1416 + fl) * 0.4;
    vec2 cell = floor(p);
    float h = hash(cell + fl * 13.0);
    float d = length(fract(p) - 0.5);
    float dot_ = smoothstep(0.12 + h * 0.08, 0.02, d) * step(0.45, h);
    vec3 tint = mix(vec3(1.0, 0.8, 0.5), vec3(0.5, 0.75, 1.0), h);
    col += tint * dot_ * (0.18 + 0.35 * uBeat) * (1.0 - fl * 0.4);
  }
  // La boule : disque à facettes scintillantes.
  vec2 bp = uv - vec2(0.0, 0.22);
  float r = length(bp);
  if (r < 0.20) {
    // Facettes : quantification de la direction, éclat aléatoire animé.
    vec2 facet = floor(bp * 46.0);
    float sparkle = hash(facet + floor(uTime * 6.0) * 0.13);
    float shade = 0.25 + 0.75 * pow(max(0.0, 1.0 - r / 0.20), 0.6);
    col = vec3(0.35, 0.37, 0.42) * shade * (0.5 + 0.5 * sparkle);
    col += vec3(1.0) * step(0.965, sparkle) * (0.6 + 0.4 * uBeat);
  }
  col += vec3(1.0, 0.95, 0.85) * smoothstep(0.23, 0.19, r) * smoothstep(0.19, 0.21, r) * 0.25;
  // Tige.
  col += vec3(0.2) * step(abs(uv.x), 0.004) * step(0.42, uv.y) * 0.5;
  // Halo ambiant qui pulse.
  col += vec3(0.12, 0.08, 0.18) * exp(-r * 2.5) * (0.4 + 0.6 * uBeat);
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Foule en contre-jour : têtes qui sautent sur le kick, rayons derrière.
const BG_FOULE = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  // Rayons de scène derrière la foule.
  float a = atan(uv.x, 0.55 - uv.y);
  float rays = pow(0.5 + 0.5 * sin(a * 9.0 + uMeasure * 6.2831), 3.0);
  vec3 col = vec3(0.02, 0.01, 0.04);
  vec3 back = mix(vec3(1.0, 0.25, 0.45), vec3(0.25, 0.5, 1.0),
                  0.5 + 0.5 * sin(uMeasure * 3.1416));
  col += back * rays * smoothstep(-0.5, 0.55, uv.y) * (0.22 + 0.38 * uBeat);
  col += back * exp(-length(uv - vec2(0.0, 0.45)) * 2.0) * 0.35;
  // Foule : silhouettes de têtes et d'épaules, sauts calés sur le beat.
  float x = uv.x * 9.0;
  float id = floor(x);
  float h = hash(vec2(id, 3.0));
  float jump = uBeat * (0.5 + 0.5 * hash(vec2(id, 7.0))) * 0.10 * (0.4 + 0.6 * uEnergy);
  float headY = -0.30 + h * 0.10 + jump;
  float fx = fract(x) - 0.5;
  float head = smoothstep(0.34, 0.30, length(vec2(fx, (uv.y - headY) * 2.4)));
  float shoulders = smoothstep(headY - 0.06, headY - 0.10, uv.y);
  float crowd = max(head, shoulders);
  // Deuxième rang, plus bas et plus sombre.
  float x2 = uv.x * 12.0 + 4.7;
  float id2 = floor(x2);
  float jump2 = uBeat * hash(vec2(id2, 9.0)) * 0.06;
  float headY2 = -0.42 + hash(vec2(id2, 5.0)) * 0.07 + jump2;
  float head2 = smoothstep(0.36, 0.30, length(vec2(fract(x2) - 0.5, (uv.y - headY2) * 2.2)));
  float crowd2 = max(head2, smoothstep(headY2 - 0.04, headY2 - 0.08, uv.y));
  col = mix(col, vec3(0.012, 0.01, 0.02), clamp(crowd2 * 0.85 + crowd, 0.0, 1.0));
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// --- Fonds : Ville -----------------------------------------------------------

// Skyline nocturne : immeubles en silhouettes, fenêtres qui clignotent.
const BG_SKYLINE = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = mix(vec3(0.02, 0.02, 0.06), vec3(0.10, 0.06, 0.16), clamp(uv.y + 0.6, 0.0, 1.0));
  // Halo urbain à l'horizon.
  col += vec3(0.30, 0.12, 0.28) * exp(-pow((uv.y + 0.18) * 4.0, 2.0)) * (0.5 + 0.3 * uLow);
  // Deux plans d'immeubles.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = mix(7.0, 12.0, fl);
    float x = uv.x * scale + fl * 37.0 + uMeasure * (0.3 + fl * 0.4);
    float b = floor(x);
    float h = hash(vec2(b, fl * 5.0)) * 0.45 + 0.05 - fl * 0.10;
    float top = h - 0.18;
    float inBld = step(uv.y, top) * step(abs(fract(x) - 0.5), 0.42);
    vec3 bld = mix(vec3(0.05, 0.05, 0.09), vec3(0.02, 0.02, 0.04), fl);
    // Fenêtres : grille fine, allumage aléatoire animé par les mediums.
    vec2 win = vec2(fract(x * 6.0), fract((uv.y + 0.5) * 26.0));
    float wOn = step(0.65, hash(vec2(floor(x * 6.0), floor((uv.y + 0.5) * 26.0)) + fl * 11.0)
                 + 0.20 * sin(uTime * 2.0 + b * 3.0) * uMid);
    float wMask = step(win.x, 0.55) * step(win.y, 0.5) * wOn;
    vec3 warm = mix(vec3(1.0, 0.75, 0.35), vec3(0.5, 0.8, 1.0), hash(vec2(b, 9.0)));
    col = mix(col, bld + warm * wMask * (0.5 + 0.5 * uBeat * (1.0 - fl)), inBld);
  }
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Traînées de trafic en contre-plongée : phares blancs, feux rouges.
const BG_TRAFIC = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = vec3(0.02, 0.02, 0.05);
  // Route en perspective : point de fuite au centre-haut.
  float py = 1.0 / (abs(uv.y - 0.15) + 0.05);
  float lane = uv.x * py * 0.22;
  // Traînées : chaque voie porte des lumières filantes calées sur la mesure.
  for (int i = 0; i < 6; i++) {
    float fi = float(i) - 2.5;
    float d = abs(lane - fi * 0.55);
    float speed = 2.0 + hash(vec2(fi, 1.0)) * 2.0 + 3.0 * uEnergy;
    float ph = fract(py * 0.15 - uMeasure * speed + hash(vec2(fi, 7.0)));
    float streak = smoothstep(0.30, 0.0, d) * smoothstep(0.6, 0.0, ph);
    vec3 tint = fi < 0.0 ? vec3(1.0, 0.95, 0.85) : vec3(1.0, 0.15, 0.10);
    col += tint * streak * smoothstep(0.15, -0.4, uv.y) * (0.5 + 0.5 * uBeat);
  }
  // Néons flous au-dessus de la route.
  float n = fbm(uv * 3.0 + vec2(uTime * 0.05, 0.0));
  col += vec3(0.7, 0.2, 0.8) * n * smoothstep(0.0, 0.5, uv.y) * (0.20 + 0.15 * uMid);
  col += vec3(0.1, 0.6, 0.9) * fbm(uv * 4.0 - 3.0) * smoothstep(0.1, 0.6, uv.y) * 0.15;
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Pluie sur néons : rideau de gouttes devant des enseignes floues.
const BG_PLUIE = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  // Enseignes floues : taches colorées fbm.
  float n1 = fbm(uv * 2.4 + vec2(0.0, uTime * 0.01));
  float n2 = fbm(uv * 3.1 + 7.0);
  vec3 col = vec3(0.02, 0.02, 0.05);
  col += vec3(0.9, 0.15, 0.55) * pow(n1, 3.0) * 1.2;
  col += vec3(0.10, 0.65, 0.95) * pow(n2, 3.2) * 1.1;
  col += vec3(1.0, 0.6, 0.15) * pow(fbm(uv * 2.0 - 11.0), 4.0);
  col *= 0.5 + 0.4 * uMid + 0.4 * uBeat * 0.3;
  // Rideaux de pluie : deux couches de stries verticales rapides.
  for (int i = 0; i < 2; i++) {
    float fi = float(i);
    float sc = mix(40.0, 70.0, fi);
    float x = uv.x * sc + hash(vec2(fi, 2.0)) * 40.0;
    float colId = floor(x);
    float speed = 1.4 + hash(vec2(colId, fi)) * 1.2;
    float yph = fract(uv.y * (0.8 + fi * 0.5) - uTime * speed + hash(vec2(colId, 5.0)));
    float drop = smoothstep(0.20, 0.0, abs(fract(x) - 0.5))
               * smoothstep(0.25, 0.0, yph) * step(0.4, hash(vec2(colId, 8.0)));
    col += vec3(0.6, 0.75, 0.9) * drop * (0.25 + 0.35 * uHigh);
  }
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// --- Fonds : Machines --------------------------------------------------------

// Engrenages : disques dentés qui tournent sur la mesure, kick = à-coup.
const BG_ENGRENAGES = `
${NOISE}
float gear(vec2 p, float radius, float teeth, float spin) {
  float a = atan(p.y, p.x) + spin;
  float r = length(p);
  float edge = radius + 0.035 * radius * sign(sin(a * teeth));
  float body = smoothstep(edge + 0.008, edge - 0.008, r);
  float hub = smoothstep(radius * 0.30, radius * 0.28, r);
  float hole = smoothstep(radius * 0.14, radius * 0.16, r);
  return clamp(body - hub + (1.0 - hole) * body, 0.0, 1.0) * step(radius * 0.16, r);
}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = mix(vec3(0.03, 0.03, 0.04), vec3(0.08, 0.07, 0.07), fbm(uv * 3.0));
  float spin = uMeasure * 6.2831 * 0.25 + uBeat * 0.10;
  vec3 metal = vec3(0.55, 0.52, 0.48);
  vec3 amber = vec3(1.0, 0.65, 0.20);
  // Trois engrenages engrenés (sens alternés).
  float g1 = gear(uv - vec2(-0.45, 0.12), 0.34, 12.0, spin);
  float g2 = gear(uv - vec2(0.02, -0.18), 0.24, 9.0, -spin * 12.0 / 9.0 + 0.3);
  float g3 = gear(uv - vec2(0.48, 0.16), 0.29, 11.0, spin * 12.0 / 11.0 + 0.1);
  float g = max(g1, max(g2, g3));
  float shade = 0.6 + 0.4 * sin(atan(uv.y, uv.x) * 2.0 + spin * 2.0);
  col = mix(col, metal * shade * (0.5 + 0.5 * uLight), g);
  // Reflet ambré industriel qui monte avec les basses.
  col += amber * g * (0.10 + 0.35 * uLow + 0.25 * uBeat) * shade * 0.5;
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Pistons : colonnes qui montent et descendent en opposition de phase.
const BG_PISTONS = `
${NOISE}
void main() {
  vec2 uv = vUv;
  vec2 auv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = mix(vec3(0.03, 0.03, 0.04), vec3(0.07, 0.06, 0.06), fbm(auv * 4.0));
  float cols = 7.0;
  float x = uv.x * cols;
  float id = floor(x);
  float fx = fract(x);
  // Course sinusoïdale calée sur la mesure, phase alternée par colonne.
  float phase = uMeasure * 6.2831 * 2.0 + id * 2.4;
  float lift = 0.5 + 0.32 * sin(phase) * (0.5 + 0.5 * uEnergy);
  float body = step(abs(fx - 0.5), 0.30) * step(uv.y, lift) * step(lift - 0.42, uv.y);
  float rod = step(abs(fx - 0.5), 0.05) * step(uv.y, lift - 0.40) * step(0.08, uv.y);
  vec3 metal = vec3(0.45, 0.44, 0.42) * (0.6 + 0.5 * fx * (1.0 - fx) * 4.0);
  col = mix(col, metal * (0.5 + 0.5 * uLight), max(body, rod));
  // Tête chauffée : lueur ambrée à l'impact du kick.
  float head = smoothstep(0.05, 0.0, abs(uv.y - lift)) * step(abs(fx - 0.5), 0.30);
  col += vec3(1.0, 0.45, 0.10) * head * (0.2 + 0.8 * uBeat);
  // Vapeur au sol.
  col += vec3(0.35, 0.33, 0.30) * exp(-uv.y * 6.0) * fbm(auv * 5.0 + vec2(0.0, uTime * 0.3)) * 0.4;
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Circuits : pistes de cuivre, impulsions qui voyagent sur le beat.
const BG_CIRCUITS = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec3 col = vec3(0.015, 0.03, 0.025);
  float scale = 9.0;
  vec2 p = uv * scale;
  vec2 cell = floor(p);
  vec2 f = fract(p);
  // Pistes en L : chaque cellule route horizontalement ou verticalement.
  float dir = step(0.5, hash(cell));
  float trace = dir * smoothstep(0.10, 0.04, abs(f.y - 0.5))
              + (1.0 - dir) * smoothstep(0.10, 0.04, abs(f.x - 0.5));
  float pad = smoothstep(0.16, 0.10, length(f - 0.5));
  vec3 copper = vec3(0.10, 0.45, 0.30);
  col += copper * (trace * 0.5 + pad * 0.8);
  // Impulsions lumineuses qui parcourent les pistes, cadencées sur la mesure.
  float along = dir > 0.5 ? p.x : p.y;
  float pulse = fract(along * 0.11 - uMeasure * 2.0 + hash(cell + 3.0));
  float spark = smoothstep(0.12, 0.0, pulse) * trace;
  col += vec3(0.4, 1.0, 0.7) * spark * (0.4 + 0.6 * uBeat);
  col += vec3(0.9, 0.8, 0.3) * pad * smoothstep(0.10, 0.0, pulse) * uMid * 0.6;
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// --- Fonds : Nature ----------------------------------------------------------

// Eau : caustiques ondulantes, houle calée sur la mesure.
const BG_EAU = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec2 p = uv * 5.0;
  float t = uTime * 0.25 + uMeasure * 0.8;
  // Caustiques : réseau de crêtes fines là où deux champs d'ondes se croisent.
  float w1 = sin(p.x * 1.7 + t + sin(p.y * 2.3 + t * 0.7) * 1.4);
  float w2 = sin(p.y * 2.1 - t * 0.8 + sin(p.x * 1.9 - t * 0.5) * 1.4);
  float w3 = sin((p.x + p.y) * 1.3 + t * 0.6 + noise(p * 0.8 + t * 0.2) * 3.0);
  float c = pow(1.0 - abs(w1 * 0.5 + w2 * 0.3 + w3 * 0.2), 6.0) * 1.4;
  c += pow(max(0.0, 1.0 - abs(w2)), 8.0) * 0.5;
  vec3 deep = mix(vec3(0.01, 0.05, 0.09), vec3(0.02, 0.14, 0.20), uLight);
  vec3 caust = mix(vec3(0.15, 0.55, 0.60), vec3(0.45, 0.9, 0.85), uLight);
  vec3 col = deep + caust * c * (0.55 + 0.45 * uBeat * 0.6 + 0.3 * uLow);
  // Profondeur : plus sombre vers le bas.
  col *= mix(0.6, 1.15, vUv.y);
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Fumée : volutes fbm qui montent, éclairées par en dessous.
const BG_FUMEE = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec2 rise = vec2(uTime * 0.02, -uTime * 0.07 - uMeasure * 0.15);
  float n1 = fbm(uv * 2.0 + rise);
  float n2 = fbm(uv * 3.4 + rise * 1.6 + n1 * 1.5);
  float plume = exp(-pow(uv.x * (1.8 - n1), 2.0)) * (0.4 + 0.6 * smoothstep(0.6, -0.5, uv.y));
  float smoke = pow(n2, 1.6) * plume;
  vec3 warm = vec3(1.0, 0.55, 0.25);
  vec3 cold = vec3(0.5, 0.55, 0.65);
  vec3 col = vec3(0.015, 0.012, 0.02);
  col += mix(cold, warm, smoothstep(0.4, -0.6, uv.y)) * smoke * (0.8 + 0.5 * uLow + 0.4 * uBeat);
  // Braise à la base.
  col += warm * exp(-pow((uv.y + 0.52) * 6.0, 2.0)) * (0.15 + 0.35 * uBeat) * n1;
  col *= 0.5 + 1.0 * uLight;
  outColor = vec4(col, 1.0);
}`;

// Lucioles : particules chaudes dérivant dans un sous-bois sombre.
const BG_LUCIOLES = `
${NOISE}
vec3 fireflyLayer(vec2 uv, float scale, float speed, float size) {
  vec2 p = uv * scale + vec2(uTime * speed * 0.03, sin(uTime * 0.2) * 0.1);
  vec2 cell = floor(p);
  vec2 f = fract(p) - 0.5;
  float h = hash(cell);
  vec2 wander = 0.35 * vec2(sin(uTime * (0.4 + h) + h * 20.0), cos(uTime * (0.3 + h * 0.7) + h * 30.0));
  float d = length(f - wander);
  float blink = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(uTime * (1.0 + h * 2.0) + h * 40.0), 3.0);
  float fly = smoothstep(size, 0.0, d) * step(0.55, h) * blink;
  return vec3(1.0, 0.85, 0.35) * fly;
}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  // Sous-bois : troncs sombres suggérés par du bruit vertical.
  float trees = fbm(vec2(uv.x * 4.0, uv.y * 0.5));
  vec3 col = mix(vec3(0.01, 0.02, 0.015), vec3(0.03, 0.06, 0.04), trees) * (0.5 + 0.9 * uLight);
  col += fireflyLayer(uv, 5.0, 1.0, 0.05) * (0.7 + 0.6 * uLow + 0.5 * uBeat);
  col += fireflyLayer(uv + 3.7, 8.0, -0.7, 0.035) * (0.5 + 0.5 * uHigh);
  col += fireflyLayer(uv + 9.1, 12.0, 0.4, 0.025) * 0.4;
  // Clair de lune diffus en haut.
  col += vec3(0.10, 0.14, 0.20) * exp(-pow((uv.y - 0.45) * 3.0, 2.0)) * uLight;
  outColor = vec4(col, 1.0);
}`;

// --- Fonds : Miroir (placeholders — caméra du téléphone au jalon 5) ----------

// Kaléidoscope de matière colorée, rotation lente sur la mesure.
const BG_KALEIDO = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  float a = atan(uv.y, uv.x) + uMeasure * 0.8;
  float r = length(uv);
  float seg = 6.2831 / 8.0;
  a = abs(mod(a, seg) - seg * 0.5);
  vec2 p = vec2(cos(a), sin(a)) * r;
  float n1 = fbm(p * 3.0 + vec2(uTime * 0.05, uMeasure * 0.3));
  float n2 = fbm(p * 5.0 - uTime * 0.04);
  vec3 col = vec3(0.02, 0.01, 0.04);
  col += vec3(0.9, 0.2, 0.5) * pow(n1, 2.0) * (0.8 + 0.5 * uBeat);
  col += vec3(0.2, 0.7, 0.9) * pow(n2, 2.4) * (0.7 + 0.5 * uMid);
  col += vec3(1.0, 0.8, 0.3) * pow(n1 * n2, 4.0) * 2.0;
  col *= smoothstep(1.2, 0.3, r) * (0.55 + 0.9 * uLight);
  outColor = vec4(col, 1.0);
}`;

// Chrome liquide : reflets métalliques mouvants (esprit « miroir »).
const BG_CHROME = `
${NOISE}
void main() {
  vec2 uv = (vUv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
  vec2 flow = vec2(uTime * 0.03, uMeasure * 0.10);
  float n = fbm(uv * 2.6 + flow + fbm(uv * 3.0 - flow) * 0.9);
  // Pseudo-normale : dérivée du bruit -> bandes de reflets.
  float band = sin(n * 12.0 + uv.y * 4.0 + uBeat * 1.5);
  float sharp = pow(0.5 + 0.5 * band, 6.0);
  vec3 dark = vec3(0.04, 0.05, 0.07);
  vec3 steel = vec3(0.55, 0.60, 0.68);
  vec3 warm = vec3(0.9, 0.75, 0.55);
  vec3 col = mix(dark, steel, 0.35 + 0.65 * n);
  col += mix(steel, warm, 0.5 + 0.5 * sin(uTime * 0.2)) * sharp * (0.6 + 0.4 * uBeat);
  col *= 0.5 + 1.0 * uLight;
  outColor = vec4(col, 1.0);
}`;

export const BACKGROUNDS: Record<string, string> = {
  'cosmos-sun': BG_SUN,
  'cosmos-stars': BG_STARS,
  'cosmos-nebula': BG_NEBULA,
  'cosmos-rings': BG_RINGS,
  'campagne-collines': BG_COLLINES,
  'campagne-ble': BG_BLE,
  'campagne-nuages': BG_NUAGES,
  'danse-spots': BG_SPOTS,
  'danse-disco': BG_DISCO,
  'danse-foule': BG_FOULE,
  'ville-skyline': BG_SKYLINE,
  'ville-trafic': BG_TRAFIC,
  'ville-pluie': BG_PLUIE,
  'machines-engrenages': BG_ENGRENAGES,
  'machines-pistons': BG_PISTONS,
  'machines-circuits': BG_CIRCUITS,
  'nature-eau': BG_EAU,
  'nature-fumee': BG_FUMEE,
  'nature-lucioles': BG_LUCIOLES,
  'miroir-kaleido': BG_KALEIDO,
  'miroir-chrome': BG_CHROME,
};

// --- Motifs superposés (rendus sur noir, fusion additive) ------------------
// Uniforms additionnels : uOpacity (fondu), uPulse (0..1, force de pulsation).
// Les motifs appartiennent aux styles (brief) : chaque style a les siens.

// Retrofutur : grille néon inclinée.
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

// Retrofutur : petit soleil / halo à bandes.
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

// Retrofutur : boucle néon (lissajous) qui tourne, épaisseur pulsée.
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

// Vintage : poussières et rayures de pellicule qui dérivent.
const OV_POUSSIERES = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec3 col = vec3(0.0);
  // Grains qui flottent lentement.
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec2 p = uv * (4.0 + fi * 3.0) + vec2(uTime * (0.05 + fi * 0.04), -uTime * (0.08 + fi * 0.03));
    vec2 cell = floor(p);
    float h = hash(cell + fi * 17.0);
    float d = length(fract(p) - 0.5 - 0.3 * vec2(hash(cell + 3.0) - 0.5, hash(cell + 5.0) - 0.5));
    float speck = smoothstep(0.05 + h * 0.04, 0.0, d) * step(0.8, h);
    col += vec3(1.0, 0.95, 0.85) * speck * (0.3 + 0.4 * h);
  }
  // Rayure verticale fugace.
  float sx = fract(hash(vec2(floor(uTime * 1.3), 1.0)) + 0.0001);
  float scratch = smoothstep(0.004, 0.0, abs(vUv.x - sx)) * step(0.7, hash(vec2(floor(uTime * 1.3), 2.0)));
  col += vec3(0.9, 0.85, 0.75) * scratch * 0.5;
  float mask = smoothstep(1.4, 0.5, length(uv));
  outColor = vec4(col * mask * uOpacity * (0.5 + 0.5 * uPulse), 1.0);
}`;

// Vintage : formes simples — cercles concentriques qui respirent.
const OV_CERCLES = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float d = length(uv);
  float breathe = 1.0 + 0.10 * uPulse * uBeat + 0.05 * sin(uTime * 0.7);
  float rings = abs(fract(d * 3.0 / breathe - uMeasure * 0.5) - 0.5);
  float line = smoothstep(0.16, 0.02, rings) * smoothstep(1.0, 0.2, d);
  vec3 warm = vec3(0.95, 0.80, 0.55);
  outColor = vec4(warm * line * uOpacity * (0.4 + 0.3 * uLow), 1.0);
}`;

// 70's : spirale chaude qui tourne sur la mesure.
const OV_SPIRALE = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float a = atan(uv.y, uv.x);
  float r = length(uv) + 0.0001;
  float twist = a + log(r) * 3.5 - uMeasure * 6.2831 * 0.5 - uTime * 0.2;
  float arm = 0.5 + 0.5 * sin(twist * 3.0);
  float band = pow(arm, 3.0 - uPulse * uBeat * 1.5);
  vec3 orange = vec3(1.0, 0.55, 0.15);
  vec3 brun = vec3(0.55, 0.30, 0.10);
  vec3 col = mix(brun, orange, band) * band;
  col *= smoothstep(1.1, 0.2, r);
  outColor = vec4(col * uOpacity * (0.5 + 0.4 * uLow), 1.0);
}`;

// 70's : ondes concentriques moutarde, houle douce.
const OV_ONDE = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float d = length(uv);
  float wave = sin(d * 14.0 - uTime * 1.2 - uMeasure * 6.2831) * 0.5 + 0.5;
  wave = pow(wave, 2.5 - uPulse * uBeat);
  vec3 moutarde = vec3(0.90, 0.70, 0.20);
  vec3 col = moutarde * wave * smoothstep(1.1, 0.15, d);
  outColor = vec4(col * uOpacity * (0.4 + 0.4 * uMid), 1.0);
}`;

// Punk : trame de photocopie — points de demi-teinte grossiers.
const OV_TRAME = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  // Grille tournée de 45°, taille de point pilotée par le kick.
  vec2 p = mat2(0.707, -0.707, 0.707, 0.707) * uv * 14.0;
  float cell = hash(floor(p + floor(uTime * 3.0)));
  float d = length(fract(p) - 0.5);
  float dot_ = step(d, 0.15 + 0.25 * cell * (0.5 + 0.8 * uPulse * uBeat));
  float mask = smoothstep(1.2, 0.5, length(uv));
  vec3 col = vec3(1.0) * dot_ * mask;
  // Pointe de rouge punk sur certains points.
  col = mix(col, vec3(1.0, 0.1, 0.1), step(0.85, cell) * dot_);
  outColor = vec4(col * uOpacity * 0.5, 1.0);
}`;

// Punk : éclats — barres diagonales brutales qui claquent sur le kick.
const OV_ECLATS = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float slot = floor(uTime * 4.0 + uBeat * 2.0);
  float a = hash(vec2(slot, 1.0)) * 3.1416;
  vec2 dir = vec2(cos(a), sin(a));
  float stripe = fract(dot(uv, dir) * (3.0 + hash(vec2(slot, 2.0)) * 5.0) + hash(vec2(slot, 3.0)));
  float bar = step(stripe, 0.18 + 0.20 * uPulse * uBeat) * step(0.35, hash(vec2(slot, 4.0)) + uBeat * 0.5);
  vec3 col = mix(vec3(1.0), vec3(1.0, 0.08, 0.08), step(0.6, hash(vec2(slot, 5.0))));
  float mask = smoothstep(1.3, 0.6, length(uv));
  outColor = vec4(col * bar * mask * uOpacity * 0.55, 1.0);
}`;

// VHS : timecode incrusté — chiffres 7 segments qui défilent.
const OV_TIMECODE = `
float seg(vec2 p, vec2 a, vec2 b, float w) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return smoothstep(w, w * 0.4, length(pa - ba * h));
}
float digit(vec2 p, float n) {
  // 7 segments dans un cadre [0,1]², n = 0..9.
  float d = 0.0;
  float w = 0.09;
  bool s0 = n != 1.0 && n != 4.0;                              // haut
  bool s1 = n != 1.0 && n != 2.0 && n != 3.0 && n != 7.0;      // haut gauche
  bool s2 = n != 5.0 && n != 6.0;                              // haut droit
  bool s3 = n != 0.0 && n != 1.0 && n != 7.0;                  // milieu
  bool s4 = n == 0.0 || n == 2.0 || n == 6.0 || n == 8.0;      // bas gauche
  bool s5 = n != 2.0;                                          // bas droit
  bool s6 = n != 1.0 && n != 4.0 && n != 7.0;                  // bas
  if (s0) d = max(d, seg(p, vec2(0.15, 0.95), vec2(0.85, 0.95), w));
  if (s1) d = max(d, seg(p, vec2(0.10, 0.55), vec2(0.10, 0.90), w));
  if (s2) d = max(d, seg(p, vec2(0.90, 0.55), vec2(0.90, 0.90), w));
  if (s3) d = max(d, seg(p, vec2(0.15, 0.50), vec2(0.85, 0.50), w));
  if (s4) d = max(d, seg(p, vec2(0.10, 0.10), vec2(0.10, 0.45), w));
  if (s5) d = max(d, seg(p, vec2(0.90, 0.10), vec2(0.90, 0.45), w));
  if (s6) d = max(d, seg(p, vec2(0.15, 0.05), vec2(0.85, 0.05), w));
  return d;
}
void main() {
  vec2 uv = vUv;
  vec3 col = vec3(0.0);
  // « HH:MM:SS » sommaire : compteur qui tourne, secondes réelles.
  float total = floor(uTime);
  float sec = mod(total, 60.0);
  float mn = mod(floor(total / 60.0), 60.0);
  float digits[4];
  digits[0] = floor(mn / 10.0); digits[1] = mod(mn, 10.0);
  digits[2] = floor(sec / 10.0); digits[3] = mod(sec, 10.0);
  float glyph = 0.0;
  for (int i = 0; i < 4; i++) {
    float xo = 0.16 + float(i) * 0.17 + (i > 1 ? 0.08 : 0.0);
    vec2 p = (uv - vec2(xo, 0.38)) / vec2(0.13, 0.26);
    if (p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0) glyph = max(glyph, digit(p, digits[i]));
  }
  // Deux-points clignotant.
  float blink = step(0.5, fract(uTime));
  float dots = (smoothstep(0.02, 0.008, length(uv - vec2(0.55, 0.52)))
              + smoothstep(0.02, 0.008, length(uv - vec2(0.55, 0.44)))) * blink;
  // Pastille REC qui pulse sur le kick.
  float rec = smoothstep(0.05, 0.03, length((uv - vec2(0.16, 0.78)) * vec2(1.8, 1.0)));
  col += vec3(0.95) * max(glyph, dots);
  col += vec3(1.0, 0.15, 0.10) * rec * (0.5 + 0.5 * uBeat * uPulse);
  outColor = vec4(col * uOpacity * 0.8, 1.0);
}`;

// VHS : barre de tracking — bande de neige qui dérive.
const OV_TRACKING = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
  vec2 uv = vUv;
  float y = fract(0.5 + uTime * 0.07 + 0.2 * sin(uTime * 0.5));
  float band = smoothstep(0.10, 0.02, abs(uv.y - y));
  float snow = hash(vec2(floor(uv.x * 240.0), floor(uv.y * 140.0) + floor(uTime * 30.0)));
  float tear = step(0.85, hash(vec2(floor(uv.y * 60.0), floor(uTime * 8.0))));
  vec3 col = vec3(0.9) * band * snow * (0.5 + 0.5 * uPulse);
  col += vec3(0.8) * tear * band * 0.4;
  outColor = vec4(col * uOpacity * 0.6, 1.0);
}`;

// Psyché : mandala à symétrie radiale, pétales qui tournent.
const OV_MANDALA = `
vec3 hue2rgb(float h) {
  vec3 k = mod(vec3(5.0, 3.0, 1.0) + h * 6.0, 6.0);
  return 1.0 - clamp(min(k, 4.0 - k), 0.0, 1.0);
}
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float a = atan(uv.y, uv.x) + uMeasure * 1.5;
  float r = length(uv);
  float petals = 0.5 + 0.5 * cos(a * 8.0 + r * 6.0 - uTime * 0.8);
  float rings = 0.5 + 0.5 * cos(r * 18.0 - uTime * 1.5 - uBeat * uPulse * 2.0);
  float m = pow(petals * rings, 2.0) * smoothstep(1.0, 0.15, r);
  vec3 col = hue2rgb(fract(a / 6.2831 + r * 0.5 + uTime * 0.05)) * m;
  outColor = vec4(col * uOpacity * (0.5 + 0.4 * uMid), 1.0);
}`;

// Psyché : fluide — marbrures arc-en-ciel qui coulent.
const OV_FLUIDE = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
             mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
  return v;
}
vec3 hue2rgb(float h) {
  vec3 k = mod(vec3(5.0, 3.0, 1.0) + h * 6.0, 6.0);
  return 1.0 - clamp(min(k, 4.0 - k), 0.0, 1.0);
}
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec2 flow = vec2(uTime * 0.06, -uTime * 0.04);
  float n = fbm(uv * 2.0 + flow + fbm(uv * 3.0 - flow) * (1.0 + uPulse * uBeat));
  vec3 col = hue2rgb(fract(n * 1.4 + uTime * 0.04)) * pow(n, 1.5);
  col *= smoothstep(1.3, 0.4, length(uv));
  outColor = vec4(col * uOpacity * 0.7, 1.0);
}`;

// --- Motifs « motion graphics » discrets (refonte, demande utilisateur) ----
// Sobres et lumineux : fuites de lumière, bokeh, flare, matériel audio
// vintage. Faible intensité : ils habillent la vidéo sans la manger.

// Fuite de lumière chaude qui glisse lentement en diagonale.
const OV_LIGHTLEAK = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float t = uTime * 0.11;
  vec2 dir = normalize(vec2(cos(t * 0.7) * 0.6 + 0.8, sin(t) * 0.5 + 0.4));
  float band = exp(-pow(dot(uv, dir) * 1.3 + sin(t * 1.7) * 0.7, 2.0));
  float band2 = exp(-pow(dot(uv, dir.yx * vec2(-1.0, 1.0)) * 2.2 - 0.5, 2.0));
  vec3 warm = vec3(1.0, 0.45, 0.18);
  vec3 rose = vec3(1.0, 0.30, 0.38);
  vec3 col = warm * band * 0.20 + rose * band2 * 0.10;
  col *= 1.0 + uBeat * uPulse * 0.15;
  col *= smoothstep(1.6, 0.4, length(uv));
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Bokeh : quelques disques flous qui dérivent, très doux.
const OV_BOKEH = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec3 col = vec3(0.0);
  for (int i = 0; i < 7; i++) {
    float fi = float(i);
    float h = hash(vec2(fi, 1.0));
    vec2 pos = vec2(
      sin(uTime * (0.05 + h * 0.05) + fi * 2.4) * 0.8,
      cos(uTime * (0.04 + h * 0.06) + fi * 1.7) * 0.6);
    float r = 0.10 + h * 0.16;
    float d = length(uv - pos);
    float disc = smoothstep(r, r * 0.25, d);
    // Anneau doux au bord, comme un vrai bokeh d'objectif.
    disc = disc * 0.55 + smoothstep(0.06, 0.0, abs(d - r * 0.8)) * 0.45;
    vec3 tint = mix(vec3(1.0, 0.75, 0.45), vec3(0.45, 0.7, 1.0), h);
    col += tint * disc * 0.085 * (1.0 + uBeat * uPulse * 0.3);
  }
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Flare anamorphique : strie horizontale bleutée + cœur chaud, discret.
const OV_FLARE = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec2 p = vec2(sin(uTime * 0.07) * 0.5, cos(uTime * 0.09) * 0.35);
  vec2 d = uv - p;
  float streak = exp(-pow(d.y * 11.0, 2.0)) * exp(-abs(d.x) * 1.7);
  float core = exp(-length(d) * 7.0);
  float ring = smoothstep(0.05, 0.0, abs(length(d) - 0.42)) * 0.35;
  vec3 col = vec3(0.35, 0.6, 1.0) * streak * 0.30
           + vec3(1.0, 0.8, 0.55) * core * 0.5
           + vec3(0.5, 0.65, 1.0) * ring * 0.2;
  col *= 1.0 + uBeat * uPulse * 0.25;
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Enceinte vintage : boomer qui pompe sur le kick, tweeter, caisse esquissée.
const OV_SPEAKER = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec3 col = vec3(0.0);
  float kick = uBeat * uPulse;
  // Caisse : liseré arrondi à peine suggéré.
  vec2 b = abs(uv) - vec2(0.78, 0.92);
  float box = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0);
  col += vec3(0.55, 0.38, 0.22) * smoothstep(0.015, 0.0, abs(box)) * 0.4;
  // Boomer : centre bas, le cône pompe sur le kick.
  vec2 wp = uv - vec2(0.0, -0.28);
  float wr = length(wp) / (1.0 + kick * 0.06);
  vec3 warm = vec3(1.0, 0.72, 0.42);
  // Suspension + saladier : deux anneaux.
  col += warm * smoothstep(0.022, 0.0, abs(wr - 0.50)) * 0.65;
  col += warm * smoothstep(0.015, 0.0, abs(wr - 0.44)) * 0.30;
  // Ondulations du cône, resserrées vers le centre.
  float cone = sin(wr * 34.0) * 0.5 + 0.5;
  col += warm * pow(cone, 3.0) * smoothstep(0.44, 0.16, wr) * 0.14 * (1.0 + kick * 0.8);
  // Cache-noyau bombé.
  col += vec3(1.0, 0.85, 0.6) * smoothstep(0.15, 0.02, wr) * (0.22 + kick * 0.25);
  // Tweeter en haut.
  vec2 tp = uv - vec2(0.0, 0.55);
  float tr = length(tp) / (1.0 + kick * 0.02);
  col += warm * smoothstep(0.015, 0.0, abs(tr - 0.16)) * 0.5;
  col += vec3(1.0, 0.9, 0.7) * smoothstep(0.05, 0.01, tr) * (0.15 + uHigh * 0.25);
  outColor = vec4(col * uOpacity, 1.0);
}`;

// VU-mètre à aiguille : cadran chaud rétroéclairé, aiguille sur les basses.
const OV_VUMETRE = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec3 col = vec3(0.0);
  vec2 pivot = vec2(0.0, -0.55);
  vec2 d = uv - pivot;
  float r = length(d);
  float ang = atan(d.x, d.y); // 0 = vertical
  // Fond de cadran rétroéclairé ambre, très doux, borné en arc.
  float dial = smoothstep(0.95, 0.35, r) * smoothstep(0.98, 0.85, abs(ang))
             * step(0.0, d.y) * smoothstep(0.08, 0.2, r);
  col += vec3(1.0, 0.62, 0.22) * dial * 0.12;
  // Graduations en arc.
  float tick = smoothstep(0.012, 0.004, abs(fract(ang * 6.0 / 3.1416 + 0.5) - 0.5) * 0.5236)
             * smoothstep(0.03, 0.0, abs(r - 0.82)) ;
  col += vec3(1.0, 0.85, 0.6) * tick * step(abs(ang), 0.9) * 0.8;
  // Zone rouge à droite.
  col += vec3(1.0, 0.15, 0.1) * smoothstep(0.05, 0.0, abs(r - 0.82))
       * step(0.55, ang) * step(ang, 0.9) * 0.45;
  // Aiguille : angle piloté par les basses.
  float target = mix(-0.85, 0.85, clamp(uLow * 1.25 + uBeat * 0.15, 0.0, 1.0));
  float needle = smoothstep(0.014, 0.004, abs(ang - target) * r) * step(r, 0.9) * step(0.05, r);
  col += vec3(1.0, 0.95, 0.85) * needle * 0.9;
  // Témoin de crête.
  col += vec3(1.0, 0.2, 0.12) * smoothstep(0.06, 0.01, length(uv - vec2(0.62, 0.32)))
       * smoothstep(0.72, 0.85, uLow);
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Oscilloscope : trait fin phosphore qui suit les niveaux.
const OV_OSCILLO = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float t = uTime * 2.0;
  float y = 0.45 * uLow * sin(uv.x * 3.1 + t)
          + 0.22 * uMid * sin(uv.x * 7.3 - t * 1.6)
          + 0.10 * uHigh * sin(uv.x * 15.7 + t * 2.4);
  float line = exp(-pow((uv.y - y) * 26.0, 2.0));
  float glow = exp(-pow((uv.y - y) * 7.0, 2.0)) * 0.25;
  vec3 phosphor = vec3(0.55, 1.0, 0.65);
  vec3 col = phosphor * (line * 0.75 + glow) * (0.8 + uBeat * uPulse * 0.4);
  col *= smoothstep(1.05, 0.85, abs(uv.x));
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Micrographics : crochets d'angle + réticule fin, respiration sur le beat.
const OV_HUD = `
float seg2(vec2 p, vec2 a, vec2 b, float w) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return smoothstep(w, w * 0.35, length(pa - ba * h));
}
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec3 col = vec3(0.0);
  float w = 0.012;
  float breathe = 0.78 + uBeat * uPulse * 0.03;
  // Quatre crochets d'angle.
  for (int sx = 0; sx < 2; sx++) {
    for (int sy = 0; sy < 2; sy++) {
      vec2 s = vec2(sx == 0 ? -1.0 : 1.0, sy == 0 ? -1.0 : 1.0);
      vec2 c = s * breathe;
      float m = seg2(uv, c, c - vec2(s.x * 0.22, 0.0), w)
              + seg2(uv, c, c - vec2(0.0, s.y * 0.22), w);
      col += vec3(0.92, 0.9, 0.82) * min(m, 1.0) * 0.5;
    }
  }
  // Réticule central : croix fine + cercle discret.
  float cross_ = seg2(uv, vec2(-0.07, 0.0), vec2(0.07, 0.0), w * 0.8)
               + seg2(uv, vec2(0.0, -0.07), vec2(0.0, 0.07), w * 0.8);
  float ring = smoothstep(0.008, 0.002, abs(length(uv) - 0.16));
  // Tirets latéraux.
  float dash = seg2(uv, vec2(-0.5, 0.0), vec2(-0.42, 0.0), w * 0.8)
             + seg2(uv, vec2(0.42, 0.0), vec2(0.5, 0.0), w * 0.8);
  col += vec3(0.92, 0.9, 0.82) * (min(cross_, 1.0) * 0.45 + ring * 0.3 + min(dash, 1.0) * 0.35);
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Micrographics : cadran gradué fin, index lumineux qui parcourt la mesure.
const OV_TICKS = `
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  float r = length(uv);
  float ang = atan(uv.y, uv.x);
  vec3 ink = vec3(0.92, 0.9, 0.82);
  vec3 col = vec3(0.0);
  // Cercle fin.
  col += ink * smoothstep(0.006, 0.002, abs(r - 0.62)) * 0.35;
  // Graduations : 60 fines, 12 longues.
  float a60 = abs(fract(ang / 6.2831 * 60.0) - 0.5) * 2.0;
  float a12 = abs(fract(ang / 6.2831 * 12.0) - 0.5) * 2.0;
  float tickS = smoothstep(0.90, 0.99, a60) * smoothstep(0.03, 0.015, abs(r - 0.655));
  float tickL = smoothstep(0.95, 0.995, a12) * smoothstep(0.05, 0.02, abs(r - 0.675));
  col += ink * (tickS * 0.35 + tickL * 0.55);
  // Index lumineux : parcourt le cadran en une mesure.
  float target = uMeasure * 6.2831 - 1.5708;
  vec2 ip = vec2(cos(target), sin(target)) * 0.62;
  col += vec3(1.0, 0.85, 0.55) * smoothstep(0.05, 0.0, length(uv - ip)) * (0.5 + 0.4 * uBeat * uPulse);
  // Petit compteur d'arc : les basses remplissent un arc interne.
  float sweep = step(ang + 1.5708 < 0.0 ? ang + 7.854 : ang + 1.5708, uLow * 6.2831);
  col += ink * smoothstep(0.005, 0.002, abs(r - 0.52)) * sweep * 0.3;
  outColor = vec4(col * uOpacity, 1.0);
}`;

// Micrographics : semis de petites croix, quelques-unes s'allument en rythme.
const OV_CROSSES = `
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
  vec2 uv = (vUv - 0.5) * 2.0;
  vec3 col = vec3(0.0);
  vec2 p = uv * 3.2;
  vec2 cell = floor(p);
  vec2 f = fract(p) - 0.5;
  float w = 0.035;
  float arm = 0.10;
  float cross_ = max(
    smoothstep(w, w * 0.4, abs(f.y)) * step(abs(f.x), arm),
    smoothstep(w, w * 0.4, abs(f.x)) * step(abs(f.y), arm));
  float h = hash(cell);
  // Base à peine visible ; certaines croix s'allument tour à tour.
  float lit = step(0.93, fract(h + uTime * 0.10)) * (0.6 + 0.4 * uBeat * uPulse);
  col += vec3(0.92, 0.9, 0.82) * cross_ * (0.10 + lit * 0.55);
  col *= smoothstep(1.4, 0.5, length(uv));
  outColor = vec4(col * uOpacity, 1.0);
}`;

export const OVERLAYS: Record<string, string> = {
  'lightleak': OV_LIGHTLEAK,
  'bokeh': OV_BOKEH,
  'flare': OV_FLARE,
  'speaker': OV_SPEAKER,
  'vumetre': OV_VUMETRE,
  'oscillo': OV_OSCILLO,
  'hud': OV_HUD,
  'ticks': OV_TICKS,
  'crosses': OV_CROSSES,
  'grid': OV_GRID,
  'sun': OV_SUN,
  'loop': OV_LOOP,
  'poussieres': OV_POUSSIERES,
  'cercles': OV_CERCLES,
  'spirale': OV_SPIRALE,
  'onde': OV_ONDE,
  'trame': OV_TRAME,
  'eclats': OV_ECLATS,
  'timecode': OV_TIMECODE,
  'tracking': OV_TRACKING,
  'mandala': OV_MANDALA,
  'fluide': OV_FLUIDE,
};

// --- Fond vidéo --------------------------------------------------------------
// Texture d'un élément <video>, recadrée en « cover » sur le 854 × 480.
// La règle de lumière est la même que pour les fonds shaders ; les styles
// s'appliquent ensuite dans le post-traitement.

export const VIDEO_FRAGMENT = `#version 300 es
precision highp float;
in vec2 vUv;
out vec4 outColor;
uniform sampler2D uTex;
uniform vec2 uCover;   // échelle uv du recadrage cover
uniform float uLight;
uniform float uBeat;
uniform float uEnergy;
void main() {
  vec2 uv = (vUv - 0.5) * uCover + 0.5;
  uv.y = 1.0 - uv.y; // les textures vidéo arrivent ligne du haut en premier
  vec3 col = texture(uTex, uv).rgb;
  // Légère pulsation de luminosité sur le kick, proportionnelle à l'énergie.
  col *= 1.0 + uBeat * uEnergy * 0.12;
  col *= 0.55 + 0.9 * uLight;
  outColor = vec4(col, 1.0);
}`;

// --- Motif vidéo (boucle VJ) --------------------------------------------------
// Boucle « motifs lumineux sur fond noir » plaquée sur le quad des motifs,
// fusion additive comme les motifs shaders. Pulsation de luminosité sur le
// kick, proportionnelle à uPulse.

export const OVERLAY_VIDEO_FRAGMENT = `#version 300 es
precision highp float;
in vec2 vUv;
out vec4 outColor;
uniform sampler2D uTex;
uniform float uOpacity;
uniform float uPulse;
uniform float uBeat;
void main() {
  vec2 uv = vec2(vUv.x, 1.0 - vUv.y);
  vec3 col = texture(uTex, uv).rgb;
  // Coupe le voile résiduel des noirs compressés (fusion additive propre).
  col = max(col - 0.04, 0.0) * 1.04;
  col *= 1.0 + uBeat * uPulse * 0.35;
  outColor = vec4(col * uOpacity, 1.0);
}`;

// --- Post-traitement -------------------------------------------------------
// Chaîne unique paramétrée : chaque filtre a une intensité 0..1 (0 = inactif).
// Un preset de style = un sous-ensemble de ces filtres (voir /catalog).
// Ordre : déformations d'échantillonnage (kaléido, glitch, vhs), chroma,
// bloom, couleur (chaleur, sépia, photocopie, posterize, teinte), texture
// (lignes vhs, grain, vignettage), puis noir / flash.

export const POST_FRAGMENT = `#version 300 es
precision highp float;
in vec2 vUv;
out vec4 outColor;
uniform sampler2D uScene;
uniform float uTime;
uniform float uBeat;
uniform float uBloom;
uniform float uChroma;
uniform float uPosterize;
uniform float uHue;
uniform float uGrain;
uniform float uVignette;
uniform float uSepia;
uniform float uWarmth;
uniform float uPhotocopy;
uniform float uGlitch;
uniform float uVhs;
uniform float uKaleido;
uniform float uHueRot;
uniform float uFlash;
uniform float uBlack;
uniform vec2 uRes;

float phash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 hueShift(vec3 c, float a) {
  const vec3 k = vec3(0.57735);
  return c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cos(a));
}

void main() {
  vec2 px = 1.0 / uRes;
  vec2 uv = vUv;

  // Kaléidoscope : repli radial, fondu avec l'image droite selon l'intensité.
  if (uKaleido > 0.001) {
    vec2 c = uv - 0.5;
    c.x *= uRes.x / uRes.y;
    float a = atan(c.y, c.x) + uTime * 0.05;
    float r = length(c);
    float seg = 6.2831 / 6.0;
    a = abs(mod(a, seg) - seg * 0.5);
    vec2 k = vec2(cos(a), sin(a)) * r;
    k.x /= uRes.x / uRes.y;
    uv = mix(uv, clamp(k + 0.5, 0.0, 1.0), clamp(uKaleido, 0.0, 1.0));
  }

  // Glitch punk : tranches horizontales déplacées au hasard.
  if (uGlitch > 0.001) {
    float slice = floor(uv.y * 14.0 + floor(uTime * 6.0) * 3.0);
    float h = phash(vec2(slice, floor(uTime * 6.0)));
    float on = step(1.0 - 0.45 * uGlitch * (0.4 + 0.6 * uBeat), h);
    uv.x = fract(uv.x + on * (phash(vec2(slice, 7.0)) - 0.5) * 0.18 * uGlitch);
  }

  // VHS : ondulation des lignes et saut d'image occasionnel.
  if (uVhs > 0.001) {
    float line = floor(uv.y * uRes.y);
    uv.x += (phash(vec2(line, floor(uTime * 15.0))) - 0.5) * 0.004 * uVhs;
    uv.x += sin(uv.y * 90.0 + uTime * 12.0) * 0.0015 * uVhs;
    float jump = step(0.94, phash(vec2(floor(uTime * 2.0), 3.0))) * uVhs;
    uv.y = fract(uv.y + jump * 0.05 * sin(uTime * 40.0));
  }

  // Décalage chromatique : radial (retrofutur) + horizontal (bavure VHS).
  vec2 dir = (uv - 0.5) * uChroma * 0.02 + vec2(0.0035, 0.0) * uVhs;
  vec3 col;
  col.r = texture(uScene, uv + dir).r;
  col.g = texture(uScene, uv).g;
  col.b = texture(uScene, uv - dir).b;

  // Bloom approché : moyenne élargie des voisins brillants.
  float bloomAmt = max(uBloom, uWarmth * 0.5); // le halo 70's passe par là
  if (bloomAmt > 0.001) {
    vec3 acc = vec3(0.0);
    for (int x = -2; x <= 2; x++)
      for (int y = -2; y <= 2; y++)
        acc += texture(uScene, uv + vec2(float(x), float(y)) * px * 2.5).rgb;
    acc /= 25.0;
    vec3 boost = max(acc - 0.35, 0.0) * bloomAmt * 1.6;
    if (uWarmth > 0.001) boost *= vec3(1.15, 0.95, 0.7); // halo chaud
    col += boost;
  }

  // 70's : tons chauds, saturation douce.
  if (uWarmth > 0.001) {
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 warm = col * vec3(1.12, 0.98, 0.78) + vec3(0.05, 0.02, 0.0) * luma;
    warm = mix(vec3(luma), warm, 0.85); // désature légèrement
    col = mix(col, warm, uWarmth);
  }

  // Vintage : sépia délavé.
  if (uSepia > 0.001) {
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 sep = vec3(luma) * vec3(1.05, 0.90, 0.68) + vec3(0.04, 0.02, 0.0);
    col = mix(col, sep, uSepia * 0.85);
  }

  // Punk : photocopie — seuillage noir/blanc dur, accent rouge.
  if (uPhotocopy > 0.001) {
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    float th = 0.30 + 0.15 * sin(uTime * 0.7);
    float bw = smoothstep(th - 0.04, th + 0.04, luma);
    vec3 photo = vec3(bw);
    // Les zones les plus brillantes virent au rouge sur le kick.
    photo = mix(photo, vec3(1.0, 0.05, 0.05), step(0.75, luma) * (0.4 + 0.6 * uBeat));
    col = mix(col, photo, uPhotocopy);
  }

  if (uPosterize > 0.001) {
    float levels = mix(24.0, 4.0, uPosterize);
    col = floor(col * levels) / levels;
  }
  if (abs(uHue) > 0.001) col = hueShift(col, uHue);
  // Psyché : rotation de teinte continue, vitesse = intensité.
  if (uHueRot > 0.001) col = hueShift(col, uTime * uHueRot * 1.5);

  // VHS : lignes de balayage, bruit, couleurs baveuses (désaturation légère).
  if (uVhs > 0.001) {
    float scan = 0.82 + 0.18 * sin(uv.y * uRes.y * 3.1416);
    col *= mix(1.0, scan, uVhs * 0.8);
    col += (phash(uv * uRes + uTime * 60.0) - 0.5) * 0.10 * uVhs;
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, mix(vec3(luma), col, 0.75), uVhs);
  }

  // Vintage : grain animé.
  if (uGrain > 0.001) {
    col += (phash(uv * uRes * 0.5 + floor(uTime * 24.0)) - 0.5) * 0.22 * uGrain;
  }

  // Vignettage.
  if (uVignette > 0.001) {
    vec2 v = (uv - 0.5) * vec2(uRes.x / uRes.y, 1.0);
    col *= 1.0 - dot(v, v) * 0.9 * uVignette;
  }

  col = mix(col, vec3(0.0), clamp(uBlack, 0.0, 1.0));
  col = mix(col, vec3(1.0), clamp(uFlash, 0.0, 1.0));
  outColor = vec4(col, 1.0);
}`;
