import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../storage/local_storage.dart';
import '../../widgets/glass_card.dart';
import 'discovery_screen.dart';
import 'submissions_screen.dart';
import '../network_visualizer.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final studentName = LocalStorage.userName;
    final rollNumber = LocalStorage.rollNumber;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Student Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: Colors.greenAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkVisualizerScreen())),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info
                GlassCard(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: Color(0x3310B981),
                          child: Icon(Icons.person_rounded, size: 40, color: Colors.greenAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          studentName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Roll: $rollNumber',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 32),

                const Text(
                  'EXAM PORTAL',
                  style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),

                _buildActionButton(
                  context: context,
                  label: 'Discover Nearby Exams',
                  icon: Icons.wifi_find_rounded,
                  color: Colors.greenAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen())),
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                _buildActionButton(
                  context: context,
                  label: 'My Submissions',
                  icon: Icons.assignment_turned_in_rounded,
                  color: Colors.amberAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmissionsScreen())),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),

                const Spacer(),
                
                const Center(
                  child: Text(
                    'Connected to Mesh Network',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 20),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
