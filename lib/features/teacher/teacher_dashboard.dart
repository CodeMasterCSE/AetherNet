import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../storage/local_storage.dart';
import '../../widgets/glass_card.dart';
import 'create_exam_screen.dart';
import 'question_bank_screen.dart';
import 'exam_results_screen.dart';
import '../network_visualizer.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final teacherName = LocalStorage.userName;
    final paperName = LocalStorage.paperName;
    final examCode = LocalStorage.examCode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Teacher Console', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: Colors.blueAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkVisualizerScreen())),
          ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info
                GlassCard(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: Color(0x333B82F6),
                          child: Icon(Icons.school_rounded, size: 40, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          teacherName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Text('Course Instructor', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        const Divider(height: 32, color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoItem('Paper', paperName),
                            _buildInfoItem('Code', examCode),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 32),

                const Text(
                  'EXAM ACTIONS',
                  style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),

                _buildActionButton(
                  context: context,
                  label: 'Create New Exam Session',
                  icon: Icons.add_task_rounded,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateExamScreen())),
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                _buildActionButton(
                  context: context,
                  label: 'Question Bank',
                  icon: Icons.library_books_rounded,
                  color: Colors.cyanAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionBankScreen())),
                ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                _buildActionButton(
                  context: context,
                  label: 'View Live Mesh Topology',
                  icon: Icons.hub_outlined,
                  color: Colors.indigoAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkVisualizerScreen())),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                _buildActionButton(
                  context: context,
                  label: 'View Exam Results',
                  icon: Icons.assignment_turned_in_rounded,
                  color: Colors.greenAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamResultsScreen())),
                ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.1, end: 0),

                const Spacer(),
                
                const Center(
                  child: Text(
                    'MeshExam P2P Engine v1.0',
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

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
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
