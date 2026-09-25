import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'local_link.dart';

LocalEngineLink createPlatformLocalLink() => IframeLink();

/// Préviz sur PC (flutter run -d chrome) : le moteur hébergé sur GitHub
/// Pages tourne dans une iframe, messages échangés par postMessage.
class IframeLink extends LocalEngineLink {
  static const _viewType = 'vjm-renderer-iframe';

  /// Par défaut le moteur publié sur Pages ; pour itérer sur le moteur en
  /// local : `npm run dev` dans /renderer puis
  /// `flutter run -d chrome --dart-define=RENDERER_URL=http://localhost:5173/`.
  static const _rendererUrl = String.fromEnvironment('RENDERER_URL',
      defaultValue: 'https://maximilien1983.github.io/vjing-master/renderer/');

  final web.HTMLIFrameElement _iframe = web.HTMLIFrameElement();
  bool _ready = false;
  final List<String> _queue = [];

  IframeLink() {
    _iframe
      ..src = _rendererUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = '#000'
      // L'iframe est purement d'affichage ; sans ça elle capte les clics
      // destinés aux contrôles Flutter posés par-dessus.
      ..style.pointerEvents = 'none';
    _iframe.addEventListener(
        'load',
        (web.Event _) {
          _ready = true;
          for (final json in _queue) {
            sendJson(json);
          }
          _queue.clear();
        }.toJS);
    web.window.addEventListener(
        'message',
        (web.MessageEvent e) {
          final data = e.data;
          if (data.isA<JSString>()) {
            final s = (data as JSString).toDart;
            if (s.startsWith('{')) handleFeedback(s);
          }
        }.toJS);
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);
  }

  @override
  Widget buildView() => const HtmlElementView(viewType: _viewType);

  @override
  void send(Map<String, dynamic> msg) => sendJson(jsonEncode(msg));

  @override
  void sendJson(String json) {
    if (!_ready) {
      _queue.add(json);
      return;
    }
    _iframe.contentWindow?.postMessage(json.toJS, '*'.toJS);
  }
}
