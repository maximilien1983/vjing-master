/// Presets des styles et univers. Jalon 2 : Retrofutur × Cosmos uniquement.
/// À terme (jalon 4) ces presets seront chargés depuis /catalog en JSON.
library;

class StylePreset {
  final String id;
  final List<String> filterIds; // filtres du moteur
  final String transitionKind; // 'crossfade' | 'cut'
  final int transitionBeats;
  const StylePreset(this.id, this.filterIds, this.transitionKind, this.transitionBeats);
}

class UniversePreset {
  final String id;
  final List<String> backgrounds; // fonds shaders du moteur
  final List<String> motifs; // motifs superposés
  const UniversePreset(this.id, this.backgrounds, this.motifs);
}

/// Retrofutur : bloom + décalage chromatique, transitions nettes sur la mesure.
const retrofutur = StylePreset('retrofutur', ['bloom', 'chroma'], 'crossfade', 2);

const cosmos = UniversePreset(
  'cosmos',
  ['cosmos-sun', 'cosmos-stars', 'cosmos-nebula', 'cosmos-rings'],
  ['grid', 'sun', 'loop'],
);
