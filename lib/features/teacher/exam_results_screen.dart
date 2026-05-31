import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../sync/sync_engine.dart';
import '../../widgets/glass_card.dart';

class ExamResultsScreen extends ConsumerWidget {
  const ExamResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final submissions = sync.examSubmissions.values.toList();
    
    // Sort by score descending
    submissions.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    // Calculate metrics
    final totalSubmissions = submissions.length;
    double totalScore = 0;
    int highSuspicionCount = 0;
    
    for (var sub in submissions) {
      totalScore += (sub.score ?? 0);
      if (sub.suspicionScore > 50) highSuspicionCount++;
    }
    final avgScore = totalSubmissions > 0 ? (totalScore / totalSubmissions).toStringAsFixed(1) : '0.0';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Exam Results', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
          child: Column(
            children: [
              // Summary Cards
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: _buildMetricCard('Total\nSubmissions', totalSubmissions.toString(), Colors.blueAccent)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('Average\nScore', avgScore, Colors.greenAccent)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('High\nSuspicion', highSuspicionCount.toString(), Colors.redAccent)),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('STUDENT RANKINGS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 8),

              // Rankings List
              Expanded(
                child: submissions.isEmpty
                    ? Center(
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.white24),
                            SizedBox(height: 16),
                            Text('No submissions yet.', style: TextStyle(color: Colors.white54, fontSize: 18)),
                          ],
                        ).animate().fadeIn(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: submissions.length,
                        itemBuilder: (context, index) {
                          final sub = submissions[index];
                          final rank = index + 1;
                          
                          Color rankColor = Colors.white70;
                          if (rank == 1) rankColor = Colors.amber;
                          if (rank == 2) rankColor = Colors.grey.shade300;
                          if (rank == 3) rankColor = Colors.brown.shade300;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GlassCard(
                              color: sub.suspicionScore > 50 ? Colors.redAccent.withOpacity(0.1) : Colors.white.withValues(alpha: 0.05),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: rankColor.withValues(alpha: 0.2),
                                  child: Text('#$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(sub.studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID: ${sub.studentId.substring(0, 8)}...', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    if (sub.suspicionScore > 0)
                                      Text('Suspicion: ${sub.suspicionScore}', style: TextStyle(color: sub.suspicionScore > 50 ? Colors.redAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${sub.score ?? 0}',
                                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                    Text('/ ${sub.totalMarks ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _buildMetricCard(String title, String value, Color color) {
    return GlassCard(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
