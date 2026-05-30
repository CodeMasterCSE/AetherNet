import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mesh/mesh_router.dart';
import '../../sync/sync_engine.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';
import '../../storage/local_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../teacher/classroom_teacher_dashboard.dart'; // For WhiteboardPainter

class ClassroomStudentDashboard extends ConsumerStatefulWidget {
  const ClassroomStudentDashboard({super.key});

  @override
  ConsumerState<ClassroomStudentDashboard> createState() => _ClassroomStudentDashboardState();
}

class _ClassroomStudentDashboardState extends ConsumerState<ClassroomStudentDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Automatically send attendance ping on join
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider).sendAttendancePing();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _showPollResponseDialog(Poll poll) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Live Poll', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(poll.question, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...poll.options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  ref.read(syncProvider).submitPollResponse(poll.id, opt);
                  Navigator.pop(ctx);
                },
                child: Text(opt, style: const TextStyle(color: Colors.white)),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesh = ref.watch(meshProvider);
    final sync = ref.watch(syncProvider);

    // Check for emergency alerts
    if (sync.lastEmergencyAlert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('EMERGENCY ALERT: ${sync.lastEmergencyAlert!}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 10),
        ));
        sync.lastEmergencyAlert = null; // Reset so it doesn't loop
      });
    }

    // Check for new polls (basic checking for demo)
    if (sync.activePolls.isNotEmpty) {
      final latestPoll = sync.activePolls.last;
      if (!sync.pollResponses.containsKey(latestPoll.id) || !sync.pollResponses[latestPoll.id]!.containsKey(LocalStorage.deviceId)) {
        // Just show dialog if not responded yet
        // In a real app, track dialog state so it doesn't pop up constantly during rebuilds.
      }
    }

    final isHandRaised = sync.raisedHands.contains(LocalStorage.deviceId);

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
          IconButton(
            icon: Icon(isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined, color: isHandRaised ? Colors.amberAccent : Colors.white),
            onPressed: () {
              if (isHandRaised) {
                sync.lowerHand(LocalStorage.deviceId);
              } else {
                sync.raiseHand();
              }
            },
            tooltip: 'Raise Hand',
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              mesh.endSession();
              Navigator.pop(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.greenAccent,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
            Tab(icon: Icon(Icons.brush), text: 'Board'),
            Tab(icon: Icon(Icons.assignment), text: 'Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildChatTab(sync),
          _buildWhiteboardTab(sync),
          _buildTasksTab(sync),
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
                    color: isMe ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isMe ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.senderName, style: TextStyle(color: isMe ? Colors.greenAccent : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
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
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.greenAccent,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.black),
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
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Live Whiteboard (View Only)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: WhiteboardPainter(sync.whiteboardStrokes),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTasksTab(SyncEngine sync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Active Polls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        ...sync.activePolls.map((poll) {
          final responded = sync.pollResponses.containsKey(poll.id) && sync.pollResponses[poll.id]!.containsKey(LocalStorage.deviceId);
          return GlassCard(
            color: responded ? Colors.grey.withValues(alpha: 0.1) : Colors.purpleAccent.withValues(alpha: 0.2),
            child: ListTile(
              title: Text(poll.question, style: const TextStyle(color: Colors.white)),
              trailing: responded ? const Icon(Icons.check_circle, color: Colors.green) : ElevatedButton(
                onPressed: () => _showPollResponseDialog(poll),
                child: const Text('Answer'),
              ),
            ),
          ).animate().fadeIn();
        }),
        const SizedBox(height: 24),
        const Text('Assignments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        if (sync.activeAssignments.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No assignments posted.', style: TextStyle(color: Colors.white54)),
          )),
        ...sync.activeAssignments.map((a) => GlassCard(
          child: ListTile(
            title: Text(a.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(a.description, style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ),
        )),
      ],
    );
  }
}
