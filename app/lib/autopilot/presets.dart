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

/// Les 6 crans de chaque rotacteur (ordre des maquettes : angles −150° à 150°).
/// Seuls Retrofutur et Cosmos ont un preset moteur au jalon 3 ; les autres
/// crans retombent dessus en attendant le catalogue du jalon 4.
const styleIds = ['vintage', '70s', 'punk', 'retrofutur', 'vhs', 'psyche'];
const styleLabels = ['Vintage', "70's", 'Punk', 'Retrofutur', 'VHS', 'Psyché'];
const universeIds = ['campagne', 'ville', 'cosmos', 'machines', 'nature', 'miroir'];
const universeLabels = ['Campagne', 'Ville', 'Cosmos', 'Machines', 'Nature', 'Miroir'];

StylePreset stylePresetFor(String id) => switch (id) {
      'retrofutur' => retrofutur,
      _ => retrofutur, // jalon 4 : presets chargés depuis /catalog
    };

UniversePreset universePresetFor(String id) => switch (id) {
      'cosmos' => cosmos,
      _ => cosmos, // jalon 4 : presets chargés depuis /catalog
    };
