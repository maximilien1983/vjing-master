import 'dart:async';
import 'dart:convert';

/// Feedback du moteur (stats, pong, plus tard sources). Voir renderer/PROTOCOL.md.
typedef EngineFeedback = void Function(Map<String, dynamic> msg);

/// Un canal vers une instance du moteur (WebView locale ou receiver Cast).
abstract class EngineLink {
  EngineFeedback? onFeedback;

  void send(Map<String, dynamic> msg);

  void sendJson(String json);

  /// Mesure la latence aller-retour app -> moteur -> app.
  final _pending = <int, Completer<Duration>>{};

  Future<Duration> ping() {
    final t = DateTime.now().millisecondsSinceEpoch;
    final completer = Completer<Duration>();
    _pending[t] = completer;
    send({'type': 'ping', 't': t});
    Future.delayed(const Duration(seconds: 3), () {
      if (_pending.remove(t) case final c?) {
        if (!c.isCompleted) c.completeError(TimeoutException('ping'));
      }
    });
    return completer.future;
  }

  /// À appeler par les implémentations pour chaque message du moteur.
  void handleFeedback(String json) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (msg['type'] == 'pong') {
      final t = msg['t'] as int?;
      final c = t == null ? null : _pending.remove(t);
      if (c != null && !c.isCompleted) {
        c.complete(Duration(
            milliseconds: DateTime.now().millisecondsSinceEpoch - t!));
      }
      return;
    }
    onFeedback?.call(msg);
  }
}
