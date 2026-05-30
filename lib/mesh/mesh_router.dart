import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/models.dart';
import '../network/discovery_service.dart';
import '../storage/local_storage.dart';
import '../security/crypto_utils.dart';

final meshProvider = ChangeNotifierProvider(
    (ref) => MeshRouter(ref.watch(nearbyServiceProvider)));

class ConnectionRequest {
  final String endpointId;
  final ConnectionInfo info;
  ConnectionRequest(this.endpointId, this.info);
}

class MeshRouter extends ChangeNotifier {
  final NearbyDiscoveryService _nearbyService;

  // Direct connections
  final Map<String, DeviceNode> connectedPeers = {}; // endpointId -> Node
  final Map<String, String> endpointToDeviceId = {}; // endpointId -> deviceId
  final Map<String, String> deviceIdToEndpoint = {}; // deviceId -> endpointId

  // Global Topology (DeviceId based)
  final Map<String, List<String>> meshTopology = {};
  final Map<String, bool> nodeRoles = {};
  final Map<String, String> nodeNames = {};
  final Map<String, DateTime> nodeTimestamps = {};
  DateTime? examEndTime;
  bool _isSessionActive = true;
  bool get isSessionActive => _isSessionActive;

  Set<String> seenMessageIds = {};
  Timer? _topologyTimer;
  Timer? _cleanupTimer;

  // Connection Approval
  final List<ConnectionRequest> pendingRequests = [];

  MeshRouter(this._nearbyService) {
    _initLocalNode();
    _startTopologyBroadcast();
    _startCleanupTimer();
  }

  void _initLocalNode() {
    final myId = LocalStorage.deviceId;
    _isSessionActive = true;
    meshTopology[myId] = [];
    nodeRoles[myId] = LocalStorage.isTeacher;
    nodeNames[myId] = LocalStorage.userName;
    nodeTimestamps[myId] = DateTime.now();
  }

  void _startTopologyBroadcast() {
    // Broadcast every 3 seconds for fast convergence
    _topologyTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (connectedPeers.isNotEmpty) {
        _broadcastTopology();
      }
    });
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      final now = DateTime.now();
      final myId = LocalStorage.deviceId;
      bool changed = false;

      nodeTimestamps.removeWhere((id, lastSeen) {
        if (id == myId) return false;
        // Keep direct peers always
        if (deviceIdToEndpoint.containsKey(id)) return false;

        // Remove nodes not seen for 15 seconds
        if (now.difference(lastSeen) > const Duration(seconds: 15)) {
          meshTopology.remove(id);
          nodeRoles.remove(id);
          nodeNames.remove(id);
          changed = true;
          return true;
        }
        return false;
      });
      if (changed) notifyListeners();
    });
  }

  void _broadcastTopology() {
    final myId = LocalStorage.deviceId;

    // We only report neighbors for whom we've received their nodeId (identity)
    final neighborDeviceIds = connectedPeers.keys
        .map((eid) => endpointToDeviceId[eid])
        .whereType<String>()
        .toList();

    // Update local view
    meshTopology[myId] = neighborDeviceIds;

    final payload = json.encode({
      'nodeId': myId,
      'name': '${LocalStorage.userName}|${LocalStorage.rollNumber}',
      'isTeacher': LocalStorage.isTeacher,
      'neighbors': neighborDeviceIds,
    });

    broadcast('MESH_TOPOLOGY_UPDATE', payload);
  }

  @override
  void dispose() {
    _topologyTimer?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  Function(MeshMessage)? onMessageReceived;
  VoidCallback? onEndSession;

  void handleConnectionInitiated(String endpointId, ConnectionInfo info) {
    if (LocalStorage.isTeacher) {
      // Teachers must approve students
      pendingRequests.add(ConnectionRequest(endpointId, info));
      notifyListeners();
    } else {
      // Students accept automatically (usually connecting to teacher)
      acceptRequest(endpointId);
    }
  }

  void acceptRequest(String endpointId) {
    pendingRequests.removeWhere((r) => r.endpointId == endpointId);
    _nearbyService.acceptConnection(endpointId, (id, payload) {
      if (payload.type == PayloadType.BYTES) {
        _handleIncomingData(endpointId, String.fromCharCodes(payload.bytes!));
      }
    });
    notifyListeners();
  }

  void rejectRequest(String endpointId) {
    pendingRequests.removeWhere((r) => r.endpointId == endpointId);
    _nearbyService.rejectConnection(endpointId);
    notifyListeners();
  }

  void handleConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      connectedPeers[endpointId] = DeviceNode(
        id: endpointId,
        name: 'Peer',
        lastSeen: DateTime.now(),
      );

      // Send an immediate topology update so the other side gets our nodeId immediately
      _broadcastTopology();

      notifyListeners();
      _syncExistingMessagesToNewPeer(endpointId);
    }
  }

  void _syncExistingMessagesToNewPeer(String endpointId) {
    try {
      final allMessages = LocalStorage.getAllMessages();
      for (final msgJson in allMessages) {
        _nearbyService.sendPayload(endpointId, json.encode(msgJson));
      }
    } catch (e) {
      debugPrint('[Mesh] Sync error: $e');
    }
  }

  void handleDisconnected(String endpointId) {
    final devId = endpointToDeviceId.remove(endpointId);
    if (devId != null) {
      deviceIdToEndpoint.remove(devId);
    }
    connectedPeers.remove(endpointId);
    notifyListeners();
  }

  void handleIncomingPayload(String senderEndpoint, String data) {
    _handleIncomingData(senderEndpoint, data);
  }

  void _handleIncomingData(String senderEndpoint, String data) {
    try {
      final jsonMsg = json.decode(data);
      final msg = MeshMessage.fromJson(jsonMsg);

      if (seenMessageIds.contains(msg.id)) return;
      if (!CryptoUtils.verifyHash(msg.payload, msg.signature)) return;

      seenMessageIds.add(msg.id);

      if (msg.type == 'MESH_TOPOLOGY_UPDATE') {
        final payload = json.decode(msg.payload);
        final nodeId = payload['nodeId'];
        final name = payload['name'];
        final isTeacher = payload['isTeacher'] ?? false;
        final neighbors = List<String>.from(payload['neighbors']);

        endpointToDeviceId[senderEndpoint] = nodeId;
        deviceIdToEndpoint[nodeId] = senderEndpoint;

        meshTopology[nodeId] = neighbors;
        nodeNames[nodeId] = name;
        nodeRoles[nodeId] = isTeacher;
        nodeTimestamps[nodeId] = DateTime.now();

        notifyListeners();
      } else if (msg.type == 'EXAM_START') {
        final payload = json.decode(msg.payload);
        final durationMinutes = payload['duration'] as int;
        examEndTime = DateTime.now().add(Duration(minutes: durationMinutes));
        notifyListeners();
      } else if (msg.type == 'END_SESSION') {
        _handleEndSession();
      } else {
        if (msg.type != 'IDENTITY') {
          LocalStorage.saveMessage(msg.id, jsonMsg);
        }
      }

      onMessageReceived?.call(msg);
      _relayMessage(msg, excludeEndpoint: senderEndpoint);
    } catch (e) {
      debugPrint('Mesh Error: $e');
    }
  }

  void _relayMessage(MeshMessage msg, {String? excludeEndpoint}) {
    if (msg.hopCount >= 10) return;
    final relayed = MeshMessage(
      id: msg.id,
      senderId: msg.senderId,
      payload: msg.payload,
      signature: msg.signature,
      hopCount: msg.hopCount + 1,
      type: msg.type,
      timestamp: msg.timestamp,
    );
    final encoded = json.encode(relayed.toJson());
    for (var eid in connectedPeers.keys) {
      if (eid != excludeEndpoint) {
        _nearbyService.sendPayload(eid, encoded);
      }
    }
  }

  void broadcast(String type, String payload) {
    final sig = CryptoUtils.generateHash(payload);
    final msg = MeshMessage(
      id: '${LocalStorage.deviceId}-${DateTime.now().millisecondsSinceEpoch}',
      senderId: LocalStorage.deviceId,
      payload: payload,
      signature: sig,
      hopCount: 0,
      type: type,
      timestamp: DateTime.now(),
    );
    seenMessageIds.add(msg.id);
    if (type != 'MESH_TOPOLOGY_UPDATE' && type != 'END_SESSION') {
      LocalStorage.saveMessage(msg.id, msg.toJson());
    }
    _relayMessage(msg);
  }

  void _handleEndSession() async {
    _isSessionActive = false;
    onEndSession?.call();

    // Clear all in-memory networking state
    connectedPeers.clear();
    endpointToDeviceId.clear();
    deviceIdToEndpoint.clear();
    meshTopology.clear();
    nodeRoles.clear();
    nodeNames.clear();
    nodeTimestamps.clear();
    seenMessageIds.clear();
    pendingRequests.clear();

    notifyListeners();
    await LocalStorage.clearSessionData();
    _nearbyService.stopAll();
    _initLocalNode();
  }

  void endSession() {
    broadcast('END_SESSION', 'Session Ended by Teacher');
    _handleEndSession();
  }
}
