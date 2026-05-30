import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mesh/mesh_router.dart';
import '../storage/local_storage.dart';

class NetworkVisualizerScreen extends ConsumerStatefulWidget {
  const NetworkVisualizerScreen({super.key});

  @override
  ConsumerState<NetworkVisualizerScreen> createState() =>
      _NetworkVisualizerScreenState();
}

class _NetworkVisualizerScreenState
    extends ConsumerState<NetworkVisualizerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  double _pulseValue = 0.0;
  
  final Map<String, Offset> _nodePositions = {};
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseController.addListener(() {
      if (mounted) {
        setState(() {
          _pulseValue = _pulseController.value;
          _updatePhysics();
        });
      }
    });
  }

  void _updatePhysics() {
    final router = ref.read(meshProvider);
    final myId = LocalStorage.deviceId;
    
    // Ensure all known nodes have a position, even if not reachable
    // This makes the visualizer more robust
    final allKnownNodes = router.meshTopology.keys.toSet();
    allKnownNodes.add(myId);
    
    final reachableNodes = _getReachableNodes(router);
    
    for (var id in reachableNodes) {
      if (!_nodePositions.containsKey(id)) {
        _nodePositions[id] = Offset(100 + _random.nextDouble() * 200, 100 + _random.nextDouble() * 200);
      }
    }
    
    // Cleanup nodes that are no longer reachable
    _nodePositions.removeWhere((key, value) => !reachableNodes.contains(key));

    if (reachableNodes.isEmpty) return;

    const kRepulsion = 20000.0;
    const kAttraction = 0.15;
    const kCenterGravity = 0.08;
    const center = Offset(200, 200);

    Map<String, Offset> velocity = {for (var id in reachableNodes) id: Offset.zero};

    // 1. Repulsion
    for (var i in reachableNodes) {
      for (var j in reachableNodes) {
        if (i == j) continue;
        final delta = _nodePositions[i]! - _nodePositions[j]!;
        final dist = delta.distance.clamp(1.0, 500.0);
        velocity[i] = velocity[i]! + (delta / dist) * (kRepulsion / (dist * dist));
      }
    }

    // 2. Attraction
    final edges = _getEdges(router, reachableNodes);
    for (var edge in edges) {
      final u = edge[0];
      final v = edge[1];
      if (!_nodePositions.containsKey(u) || !_nodePositions.containsKey(v)) continue;
      
      final delta = _nodePositions[v]! - _nodePositions[u]!;
      final dist = delta.distance;
      if (dist < 1.0) continue;
      
      final force = (dist - 140) * kAttraction;
      velocity[u] = velocity[u]! + (delta / dist) * force;
      velocity[v] = velocity[v]! - (delta / dist) * force;
    }

    // 3. Center Gravity
    for (var id in reachableNodes) {
      final delta = center - _nodePositions[id]!;
      velocity[id] = velocity[id]! + delta * kCenterGravity;
    }

    // Apply movement
    for (var id in reachableNodes) {
      _nodePositions[id] = _nodePositions[id]! + velocity[id]!.scale(0.1, 0.1);
      
      // Clamp to view area
      _nodePositions[id] = Offset(
        _nodePositions[id]!.dx.clamp(30.0, 370.0),
        _nodePositions[id]!.dy.clamp(30.0, 370.0),
      );
    }
  }

  Set<String> _getReachableNodes(MeshRouter router) {
    final myId = LocalStorage.deviceId;
    Set<String> reachable = {myId};
    List<String> queue = [myId];
    int head = 0;
    
    while (head < queue.length) {
      final u = queue[head++];
      final neighbors = router.meshTopology[u];
      if (neighbors != null) {
        for (var v in neighbors) {
          if (!reachable.contains(v)) {
            reachable.add(v);
            queue.add(v);
          }
        }
      }
    }
    return reachable;
  }

  List<List<String>> _getEdges(MeshRouter router, Set<String> reachableNodes) {
    List<List<String>> edges = [];
    Set<String> seen = {};
    
    for (var entry in router.meshTopology.entries) {
      final u = entry.key;
      if (!reachableNodes.contains(u)) continue;
      for (var v in entry.value) {
        if (!reachableNodes.contains(v)) continue;
        
        final id = u.compareTo(v) < 0 ? '$u-$v' : '$v-$u';
        if (!seen.contains(id)) {
          edges.add([u, v]);
          seen.add(id);
        }
      }
    }
    return edges;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(meshProvider);
    final reachableNodes = _getReachableNodes(router);
    final edges = _getEdges(router, reachableNodes);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Live Network Topology', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(reachableNodes.length, router.connectedPeers.length),
              Expanded(
                child: reachableNodes.length <= 1 && router.connectedPeers.isEmpty
                    ? _buildEmptyView()
                    : InteractiveViewer(
                        maxScale: 3.0,
                        minScale: 0.5,
                        child: Center(
                          child: SizedBox(
                            width: 400,
                            height: 400,
                            child: CustomPaint(
                              painter: _MeshPainter(
                                nodePositions: _nodePositions,
                                edges: edges,
                                pulseValue: _pulseValue,
                              ),
                              child: Stack(
                                children: _buildNodes(router, reachableNodes),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hub_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('Waiting for peers...', style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Scanning for mesh connections...', style: TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 24),
          // Also show "YOU" node even if lonely
          _NodeCircle(
            label: 'YOU',
            color: LocalStorage.isTeacher ? Colors.blueAccent : Colors.greenAccent,
            isMe: true,
            isTeacher: LocalStorage.isTeacher,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int direct) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatBox('Mesh Nodes', '$total', Colors.blueAccent),
          _StatBox('Direct Peers', '$direct', Colors.greenAccent),
        ],
      ).animate().fadeIn().slideY(begin: -0.2, end: 0),
    );
  }

  List<Widget> _buildNodes(MeshRouter router, Set<String> reachableNodes) {
    return reachableNodes.map((id) {
      final pos = _nodePositions[id] ?? const Offset(200, 200);
      final isMe = id == LocalStorage.deviceId;
      final isTeacher = isMe ? LocalStorage.isTeacher : (router.nodeRoles[id] ?? false);
      final label = isMe ? 'YOU' : (router.nodeNames[id] ?? id.substring(0, 4));
      final color = isTeacher ? Colors.blueAccent : Colors.greenAccent;

      return Positioned(
        left: pos.dx - 30,
        top: pos.dy - 30,
        child: _NodeCircle(
          label: label,
          color: color,
          isMe: isMe,
          isTeacher: isTeacher,
        ),
      );
    }).toList();
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendItem(Colors.blueAccent, 'Teacher'),
          _LegendItem(Colors.greenAccent, 'Student'),
          _LegendItem(Colors.white30, 'Mesh Link'),
        ],
      ),
    );
  }
}

class _NodeCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool isMe;
  final bool isTeacher;

  const _NodeCircle({
    required this.label,
    required this.color,
    required this.isMe,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(
              color: isMe ? Colors.white : color,
              width: isMe ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Icon(
            isTeacher ? Icons.school_rounded : Icons.person_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isMe ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Map<String, Offset> nodePositions;
  final List<List<String>> edges;
  final double pulseValue;

  _MeshPainter({required this.nodePositions, required this.edges, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
      
    final packetPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
    
    for (var edge in edges) {
      final p1 = nodePositions[edge[0]];
      final p2 = nodePositions[edge[1]];
      if (p1 == null || p2 == null) continue;

      canvas.drawLine(p1, p2, linePaint);
      
      // Animated packet
      final t = (pulseValue + (edges.indexOf(edge) * 0.3)) % 1.0;
      final packetPos = Offset.lerp(p1, p2, t)!;
      
      canvas.drawCircle(packetPos, 4, Paint()..color = Colors.blueAccent.withValues(alpha: 0.3));
      canvas.drawCircle(packetPos, 2.5, packetPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => true;
}
