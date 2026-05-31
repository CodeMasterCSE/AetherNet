import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';

// Unique service ID — must match on BOTH teacher and student
const String _kServiceId = 'com.meshexam.p2p';

// Platform channel to request ALL runtime permissions from native Android
const _permissionChannel = MethodChannel('meshexam/permissions');

final nearbyServiceProvider = Provider((ref) => NearbyDiscoveryService());

class NearbyDiscoveryService {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  bool _permissionsRequested = false;

  /// Requests ALL permissions in a single native call:
  /// Location + Bluetooth (API 31+) + NEARBY_WIFI_DEVICES (API 33+).
  /// Only shows the dialog once per app session.
  Future<void> requestAllPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    try {
      // Single native call that bundles ALL permissions into one dialog
      await _permissionChannel.invokeMethod('requestAllPermissions');
      debugPrint('[Permissions] All permissions requested via native channel');

      // Wait for user to respond to the permission dialog
      await Future.delayed(const Duration(seconds: 2));

      // Ensure GPS/Location service is turned on (separate from permission)
      // ignore: deprecated_member_use
      final locationEnabled = await Nearby().checkLocationEnabled();
      if (!locationEnabled) {
        debugPrint('[Permissions] Location service OFF — prompting user');
        // ignore: deprecated_member_use
        await Nearby().enableLocationServices();
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('[Permissions] Error: $e');
      _permissionsRequested = false; // Allow retry
    }
  }

  Future<void> startAdvertising(
    String userName,
    void Function(String, ConnectionInfo) onConnectionInitiated,
    void Function(String, Status) onConnectionResult,
    void Function(String) onDisconnected,
  ) async {
    try {
      await requestAllPermissions();
      final started = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: onConnectionResult,
        onDisconnected: onDisconnected,
        serviceId: _kServiceId,
      );
      debugPrint('[Nearby] Advertising started: $started');
    } catch (e) {
      debugPrint('[Nearby] Error starting advertising: $e');
    }
  }

  Future<void> startDiscovery(
    String userName,
    void Function(String, String, String) onEndpointFound,
    void Function(String?) onEndpointLost,
  ) async {
    try {
      await requestAllPermissions();
      final started = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: onEndpointFound,
        onEndpointLost: onEndpointLost,
        serviceId: _kServiceId,
      );
      debugPrint('[Nearby] Discovery started: $started');
    } catch (e) {
      debugPrint('[Nearby] Error starting discovery: $e');
    }
  }

  Future<void> requestConnection(
    String userName,
    String endpointId,
    void Function(String, ConnectionInfo) onConnectionInitiated,
    void Function(String, Status) onConnectionResult,
    void Function(String) onDisconnected,
  ) async {
    try {
      await Nearby().requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: onConnectionResult,
        onDisconnected: onDisconnected,
      );
    } catch (e) {
      debugPrint('[Nearby] Error requesting connection: $e');
    }
  }

  Future<void> acceptConnection(
    String endpointId,
    void Function(String, Payload) onPayloadReceived, {
    void Function(String, PayloadTransferUpdate)? onPayloadTransferUpdate,
  }) async {
    try {
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: onPayloadReceived,
        onPayloadTransferUpdate: onPayloadTransferUpdate ?? (id, update) {},
      );
    } catch (e) {
      debugPrint('[Nearby] Error accepting connection: $e');
    }
  }

  Future<void> rejectConnection(String endpointId) async {
    await Nearby().rejectConnection(endpointId);
  }

  Future<void> sendPayload(String endpointId, String message) async {
    try {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(message.codeUnits),
      );
    } catch (e) {
      debugPrint('[Nearby] Error sending payload: $e');
    }
  }

  Future<int> sendFilePayload(String endpointId, String filePath) async {
    try {
      return await Nearby().sendFilePayload(endpointId, filePath);
    } catch (e) {
      debugPrint('[Nearby] Error sending file payload: $e');
      return -1;
    }
  }

  Future<bool> copyFileAndDeleteOriginal(String sourceUri, String destinationFilepath) async {
    try {
      return await Nearby().copyFileAndDeleteOriginal(sourceUri, destinationFilepath);
    } catch (e) {
      debugPrint('[Nearby] Error copying file: $e');
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    await Nearby().stopAdvertising();
  }

  Future<void> stopDiscovery() async {
    await Nearby().stopDiscovery();
  }

  Future<void> stopAll() async {
    try {
      await stopAdvertising();
      await stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      debugPrint('[Nearby] Error stopping: $e');
    }
  }
}
