import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Servicio para monitorear la conectividad a internet
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = 
      StreamController<bool>.broadcast();

  bool _hasConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Stream que emite true cuando hay conexión, false cuando no
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  /// Estado actual de la conexión
  bool get hasConnection => _hasConnection;

  /// Inicializar el servicio
  Future<void> initialize() async {
    // Verificar estado inicial
    await _checkConnection();

    // Escuchar cambios de conectividad
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      await _checkConnection();
    });

    debugPrint('✅ ConnectivityService inicializado - Estado: ${_hasConnection ? "ONLINE" : "OFFLINE"}');
  }

  /// Verificar el estado de la conexión
  Future<void> _checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final bool hasConnection = results.isNotEmpty && 
          !results.contains(ConnectivityResult.none);

      // Solo emitir si el estado cambió
      if (hasConnection != _hasConnection) {
        _hasConnection = hasConnection;
        _connectionStatusController.add(_hasConnection);
        
        debugPrint(_hasConnection 
            ? '🟢 CONEXIÓN RESTAURADA' 
            : '🔴 CONEXIÓN PERDIDA');
      }
    } catch (e) {
      debugPrint('❌ Error al verificar conexión: $e');
      _hasConnection = false;
      _connectionStatusController.add(false);
    }
  }

  /// Verificar manualmente la conexión
  Future<bool> checkConnectionManually() async {
    await _checkConnection();
    return _hasConnection;
  }

  /// Disponer recursos
  void dispose() {
    _subscription?.cancel();
    _connectionStatusController.close();
  }
}