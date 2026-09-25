import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'local_link.dart';

LocalEngineLink createPlatformLocalLink() => WebViewLink();

/// Moteur dans la WebView locale (mode local, plus tard AirPlay).
/// Charge la copie single-file du moteur depuis les assets Flutter.
class WebViewLink extends LocalEngineLink {
  late final WebViewController controller;
  bool _ready = false;
  final List<String> _queue = [];

  WebViewLink() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel('VjmFeedback',
          onMessageReceived: (m) => handleFeedback(m.message))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        _ready = true;
        for (final json in _queue) {
          sendJson(json);
        }
        _queue.clear();
      }))
      ..loadFlutterAsset('assets/renderer/index.html');
  }

  @override
  Widget buildView() => WebViewWidget(controller: controller);

  @override
  void send(Map<String, dynamic> msg) => sendJson(jsonEncode(msg));

  @override
  void sendJson(String json) {
    if (!_ready) {
      _queue.add(json);
      return;
    }
    // Le JSON est passé en littéral chaîne : on échappe pour l'inclusion JS.
    final escaped = jsonEncode(json);
    controller.runJavaScript('window.VJM && window.VJM.handleMessage($escaped)');
  }
}
