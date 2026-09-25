import 'package:flutter/widgets.dart';

import 'engine_link.dart';
import 'local_link_io.dart'
    if (dart.library.js_interop) 'local_link_web.dart' as impl;

/// Moteur « local » : WebView plein écran sur mobile, iframe en préviz
/// Flutter web sur PC (flutter run -d chrome). Même protocole partout.
abstract class LocalEngineLink extends EngineLink {
  Widget buildView();
}

LocalEngineLink createLocalLink() => impl.createPlatformLocalLink();
