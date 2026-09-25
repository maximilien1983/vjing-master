/// Configuration de build. Aucun secret ici : les clés (Pixabay, jalon 4)
/// passent par --dart-define ou un fichier local ignoré par git.
library;

/// App ID du Custom Receiver, fourni par la Google Cast Developer Console
/// (voir docs/cast-setup.md). Pas un secret. Surchargable :
/// flutter run --dart-define=CAST_APP_ID=XXXXXXXX
const castAppId = String.fromEnvironment('CAST_APP_ID', defaultValue: '');

/// Namespace des messages de contrôle app <-> receiver.
const castNamespace = 'urn:x-cast:fr.vjm.control';

/// Version du protocole app -> moteur (voir renderer/PROTOCOL.md).
const protocolVersion = 1;
