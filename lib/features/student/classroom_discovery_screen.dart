import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../../mesh/mesh_router.dart';
import '../../network/discovery_service.dart';
import '../../storage/local_storage.dart';
import '../../sync/sync_engine.dart';
import 'classroom_student_dashboard.dart';

class ClassroomDiscoveryScreen extends ConsumerStatefulWidget {
  const ClassroomDiscoveryScreen({super.key});

  @override
  ConsumerState<ClassroomDiscoveryScreen> createState() => _ClassroomDiscoveryScreenState();
}

class _ClassroomDiscoveryScreenState extends ConsumerState<ClassroomDiscoveryScreen> {
  // Map of endpointId -> endpointName (teacher's device name)
  final Map<String, String> discoveredEndpoints = {};
  String? _connectingTo;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    final nearbyService = ref.read(nearbyServiceProvider);
    await nearbyService.stopAll(); // Clear any stale session
    await LocalStorage.clearSessionData(); // Reset for new discovery
    ref.read(syncProvider).reset(); // Clear in-memory state
    nearbyService.startDiscovery(
      LocalStorage.userName,
      // onEndpointFound — show teacher's session
      (endpointId, endpointName, serviceId) {
        if (mounted) {
          setState(() {
            discoveredEndpoints[endpointId] = endpointName;
            _statusMessage = null;
          });
        }
      },
      // onEndpointLost — remove from list
      (endpointId) {
        if (mounted) {
          setState(() => discoveredEndpoints.remove(endpointId));
        }
      },
    );
  }

  Future<void> _connectToEndpoint(String endpointId, String endpointName) async {
    if (_connectingTo != null) return;
    setState(() {
      _connectingTo = endpointId;
      _statusMessage = 'Connecting to $endpointName...';
    });

    final nearbyService = ref.read(nearbyServiceProvider);
    final mesh = ref.read(meshProvider);

    await nearbyService.requestConnection(
      LocalStorage.userName,
      endpointId,
      // onConnectionInitiated — student must also accept
      (id, ConnectionInfo info) async {
        if (mounted) setState(() => _statusMessage = 'Accepting handshake...');
        mesh.acceptRequest(id);
      },
      // onConnectionResult
      (id, Status status) {
        if (!mounted) return;
        if (status == Status.CONNECTED) {
          mesh.handleConnectionResult(id, status);
          // Initialize SyncEngine NOW so it's ready to receive
          ref.read(syncProvider);
          Nearby().stopDiscovery(); // Only stop discovery, don't disconnect!
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ClassroomStudentDashboard(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        } else {
          setState(() {
            _connectingTo = null;
            _statusMessage = 'Connection failed. Tap to retry.';
          });
        }
      },
      // onDisconnected
      (id) {
        mesh.handleDisconnected(id);
        if (mounted) {
          setState(() {
            _connectingTo = null;
            _statusMessage = 'Disconnected from peer.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    // Only stop discovery when leaving, don't kill active mesh links
    Nearby().stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Find Classrooms',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: discoveredEndpoints.isEmpty
              ? Align(
                  alignment: const Alignment(0, -0.2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ScanningHeader(
                        isScanning: _connectingTo == null,
                      ),
                      if (_statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                          child: Text(
                            _statusMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 14),
                          ).animate().fadeIn(),
                        ),
                      const SizedBox(height: 40),
                      const _EmptyState(),
                    ],
                  ).animate().fadeIn(duration: 800.ms),
                )
              : Column(
                  children: [
                    const SizedBox(height: 20),
                    _ScanningHeader(isScanning: _connectingTo == null),
                    if (_statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 14),
                        ).animate().fadeIn(),
                      ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: discoveredEndpoints.length,
                        itemBuilder: (context, index) {
                          final endpointId = discoveredEndpoints.keys.elementAt(index);
                          final endpointName = discoveredEndpoints[endpointId]!;
                          final isConnecting = _connectingTo == endpointId;
                          return _SessionCard(
                            endpointName: endpointName,
                            endpointId: endpointId,
                            isConnecting: isConnecting,
                            onConnect: () => _connectToEndpoint(endpointId, endpointName),
                          ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _ScanningHeader extends StatelessWidget {
  final bool isScanning;
  const _ScanningHeader({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.greenAccent.withValues(alpha: 0.1),
            border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.3), width: 2),
          ),
          child: const Icon(Icons.wifi_tethering_rounded,
              size: 40, color: Colors.greenAccent),
        )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(
                begin: 1.0,
                end: 1.1,
                duration: 1200.ms,
                curve: Curves.easeInOut)
            .then()
            .scaleXY(begin: 1.1, end: 1.0, duration: 1200.ms),
        const SizedBox(height: 16),
        Text(
          isScanning ? 'Scanning for classrooms...' : 'Classrooms found nearby!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isScanning ? Colors.white70 : Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Make sure you are near the teacher device',
          style: TextStyle(fontSize: 13, color: Colors.white38),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('No classrooms found yet.',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          SizedBox(height: 8),
          Text(
            'Ask your teacher to start a classroom session.',
            style: TextStyle(color: Colors.white30, fontSize: 13),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String endpointName;
  final String endpointId;
  final bool isConnecting;
  final VoidCallback onConnect;

  const _SessionCard({
    required this.endpointName,
    required this.endpointId,
    required this.isConnecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final parts = endpointName.split('|');
    return GestureDetector(
      onTap: isConnecting ? null : onConnect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isConnecting
                ? Colors.amberAccent.withValues(alpha: 0.5)
                : Colors.greenAccent.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: Colors.greenAccent.withValues(alpha: 0.1),
               ),
               child: const Icon(Icons.co_present_rounded,
                   color: Colors.greenAccent, size: 28),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     parts.length > 1 ? parts[1] : endpointName, // Class Name
                     style: const TextStyle(
                         fontSize: 17,
                         fontWeight: FontWeight.bold,
                         color: Colors.white),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     parts.isNotEmpty ? 'Teacher: ${parts[0]}' : 'Tap to join this classroom',
                     style: const TextStyle(fontSize: 12, color: Colors.white70),
                   ),
                 ],
               ),
             ),
             if (isConnecting)
               const SizedBox(
                 width: 24,
                 height: 24,
                 child: CircularProgressIndicator(
                     color: Colors.amberAccent, strokeWidth: 2),
               )
             else
               Container(
                 padding:
                     const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(20),
                   color: Colors.greenAccent.withValues(alpha: 0.15),
                   border: Border.all(
                       color: Colors.greenAccent.withValues(alpha: 0.5)),
                 ),
                 child: const Text('Join',
                     style: TextStyle(
                         color: Colors.greenAccent,
                         fontWeight: FontWeight.bold)),
               ),
           ],
         ),
       ),
     );
  }
}
