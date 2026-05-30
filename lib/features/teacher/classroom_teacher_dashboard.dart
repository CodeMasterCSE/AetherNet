import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mesh/mesh_router.dart';
import '../../sync/sync_engine.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';
import '../../storage/local_storage.dart';
import '../../network/discovery_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ClassroomTeacherDashboard extends ConsumerStatefulWidget {
  const ClassroomTeacherDashboard({super.key});

  @override
  ConsumerState<ClassroomTeacherDashboard> createState() => _ClassroomTeacherDashboardState();
}

class _ClassroomTeacherDashboardState extends ConsumerState<ClassroomTeacherDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();

  bool _isSessionStarted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _startClassroomMesh() async {
    final nearbyService = ref.read(nearbyServiceProvider);
    final mesh = ref.read(meshProvider);

    await nearbyService.stopAll();
    ref.read(syncProvider).reset();

    // Start advertising (no exam code needed for classroom)
    final advertName = '${LocalStorage.userName}|${LocalStorage.paperName}';
    nearbyService.startAdvertising(
      advertName,
      mesh.handleConnectionInitiated,
      mesh.handleConnectionResult,
      mesh.handleDisconnected,
    );
    
    if (mounted) {
      setState(() {
        _isSessionStarted = true;
      });
    }
  }

  void _showRequestsModal(BuildContext context, MeshRouter mesh) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pending Join Requests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: Colors.white10, height: 32),
              if (mesh.pendingRequests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No pending requests', style: TextStyle(color: Colors.white38))),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: mesh.pendingRequests.length,
                    itemBuilder: (context, index) {
                      final req = mesh.pendingRequests[index];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(req.info.endpointName, style: const TextStyle(color: Colors.white)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                              onPressed: () {
                                mesh.acceptRequest(req.endpointId);
                                Navigator.pop(context);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.redAccent),
                              onPressed: () {
                                mesh.rejectRequest(req.endpointId);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _showEmergencyDialog() {
    final msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Text('Emergency Broadcast', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: msgController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter alert message...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ref.read(syncProvider).sendEmergencyAlert(msgController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Broadcast', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPollDialog() {
    final qController = TextEditingController();
    final opt1Controller = TextEditingController();
    final opt2Controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Create Poll', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qController, decoration: const InputDecoration(labelText: 'Question', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
            TextField(controller: opt1Controller, decoration: const InputDecoration(labelText: 'Option 1', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
            TextField(controller: opt2Controller, decoration: const InputDecoration(labelText: 'Option 2', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final poll = Poll(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                question: qController.text,
                options: [opt1Controller.text, opt2Controller.text],
              );
              ref.read(syncProvider).sendPoll(poll);
              Navigator.pop(ctx);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesh = ref.watch(meshProvider);
    final sync = ref.watch(syncProvider);

    if (!_isSessionStarted) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Classroom Session', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.co_present_rounded, size: 64, color: Colors.blueAccent),
              ).animate(onPlay: (c) => c.repeat()).scaleXY(begin: 1, end: 1.05, duration: 1.seconds).then().scaleXY(begin: 1.05, end: 1),
              const SizedBox(height: 32),
              const Text('Ready to Start?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Start the mesh network so students can join.', style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _startClassroomMesh,
                icon: const Icon(Icons.power_settings_new_rounded),
                label: const Text('Start Classroom Session', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Classroom Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            Text('${mesh.connectedPeers.length} Peers Connected', style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_add_rounded, color: Colors.amberAccent),
                onPressed: () => _showRequestsModal(context, mesh),
              ),
              if (mesh.pendingRequests.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${mesh.pendingRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            onPressed: _showEmergencyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              mesh.endSession();
              ref.read(nearbyServiceProvider).stopAll();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
            Tab(icon: Icon(Icons.brush), text: 'Board'),
            Tab(icon: Icon(Icons.people), text: 'Students'),
            Tab(icon: Icon(Icons.build), text: 'Tools'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildChatTab(sync),
          _buildWhiteboardTab(sync),
          _buildStudentsTab(mesh, sync),
          _buildToolsTab(),
        ],
      ),
    );
  }

  Widget _buildChatTab(SyncEngine sync) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sync.chatMessages.length,
            itemBuilder: (context, index) {
              final msg = sync.chatMessages[index];
              final isMe = msg.senderName == LocalStorage.userName;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isMe ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.senderName, style: TextStyle(color: isMe ? Colors.blueAccent : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(msg.text, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Send announcement...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    if (_chatController.text.isNotEmpty) {
                      sync.sendChatMessage(_chatController.text);
                      _chatController.clear();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteboardTab(SyncEngine sync) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Whiteboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.clear, color: Colors.redAccent),
                label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                onPressed: () => sync.clearWhiteboard(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onPanUpdate: (details) {
                // Simplified drawing logic for simulation
                final RenderBox box = context.findRenderObject() as RenderBox;
                final offset = box.globalToLocal(details.globalPosition);
                // In a real app, collect points and send stroke on pan end.
                // For demo, we broadcast single points as strokes.
                final stroke = WhiteboardStroke(
                  points: [WhiteboardPoint(offset.dx, offset.dy)],
                  colorValue: 0xFF000000,
                  strokeWidth: 4.0,
                );
                sync.sendWhiteboardStroke(stroke);
              },
              child: CustomPaint(
                painter: WhiteboardPainter(sync.whiteboardStrokes),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsTab(MeshRouter mesh, SyncEngine sync) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mesh.meshTopology.keys.length,
      itemBuilder: (context, index) {
        final nodeId = mesh.meshTopology.keys.elementAt(index);
        final name = mesh.nodeNames[nodeId] ?? 'Unknown';
        final isRaised = sync.raisedHands.contains(nodeId);
        if (nodeId == LocalStorage.deviceId) return const SizedBox.shrink(); // Skip self
        return GlassCard(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.greenAccent, child: Text(name[0], style: const TextStyle(color: Colors.black))),
            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('ID: $nodeId', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: isRaised ? const Icon(Icons.pan_tool, color: Colors.amberAccent) : const Icon(Icons.check_circle, color: Colors.green),
          ),
        ).animate().fadeIn().slideX();
      },
    );
  }

  Widget _buildToolsTab() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildToolCard('Create Poll', Icons.poll, Colors.purpleAccent, _showPollDialog),
        _buildToolCard('Post Assignment', Icons.assignment, Colors.blueAccent, () {}),
        _buildToolCard('Share File', Icons.file_present, Colors.greenAccent, () {}),
        _buildToolCard('Attendance', Icons.people_alt, Colors.orangeAccent, () {}),
      ],
    );
  }

  Widget _buildToolCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        color: color.withValues(alpha: 0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class WhiteboardPainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  WhiteboardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round;
      
      if (stroke.points.length == 1) {
        canvas.drawPoints(PointMode.points, [Offset(stroke.points[0].x, stroke.points[0].y)], paint);
      } else {
        for (int i = 0; i < stroke.points.length - 1; i++) {
          canvas.drawLine(
            Offset(stroke.points[i].x, stroke.points[i].y),
            Offset(stroke.points[i+1].x, stroke.points[i+1].y),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
