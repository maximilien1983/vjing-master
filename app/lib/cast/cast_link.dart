import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../engine/engine_link.dart';

/// Une TV découverte sur le réseau.
class CastRoute {
  final String id;
  final String name;
  const CastRoute(this.id, this.name);
}

enum CastState { idle, connecting, connected }

/// Moteur sur Chromecast, via le Cast SDK natif Android (platform channels).
/// iOS arrive au jalon 5.
class CastLink extends EngineLink {
  static const _channel = MethodChannel('fr.vjm/cast');

  final _routesCtrl = StreamController<List<CastRoute>>.broadcast();
  final _stateCtrl = StreamController<CastState>.broadcast();
  CastState _state = CastState.idle;

  Stream<List<CastRoute>> get routes => _routesCtrl.stream;
  Stream<CastState> get states => _stateCtrl.stream;
  CastState get state => _state;

  CastLink() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onRoutes':
          final list = (call.arguments as List)
              .map((r) => CastRoute(
                  (r as Map)['id'] as String, r['name'] as String))
              .toList();
          _routesCtrl.add(list);
        case 'onSessionState':
          _state = switch (call.arguments as String) {
            'connected' => CastState.connected,
            'connecting' => CastState.connecting,
            _ => CastState.idle,
          };
          _stateCtrl.add(_state);
        case 'onMessage':
          handleFeedback(call.arguments as String);
      }
    });
  }

  Future<void> startDiscovery() => _channel.invokeMethod('startDiscovery');

  Future<void> stopDiscovery() => _channel.invokeMethod('stopDiscovery');

  Future<void> connect(String routeId) =>
      _channel.invokeMethod('connect', {'routeId': routeId});

  Future<void> disconnect() => _channel.invokeMethod('disconnect');

  @override
  void send(Map<String, dynamic> msg) => sendJson(jsonEncode(msg));

  @override
  void sendJson(String json) {
    if (_state != CastState.connected) return;
    _channel.invokeMethod('sendMessage', {'json': json});
  }

  void dispose() {
    _routesCtrl.close();
    _stateCtrl.close();
  }
}
