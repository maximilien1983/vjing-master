/// Clip vidéo jouable par le moteur (fond `kind: "video"`).
/// Classe de base commune aux clips Pixabay et au catalogue hébergé.
class EngineClip {
  final String id;
  final String url;
  const EngineClip(this.id, this.url);
}
