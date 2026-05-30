import 'package:flutter/material.dart';
import '../../storage/local_storage.dart';
import '../../widgets/glass_card.dart';

class SubmissionsScreen extends StatelessWidget {
  const SubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final messages = LocalStorage.getAllMessages();
    final answers = messages.where((m) => m['type'] == 'STUDENT_ANSWER').toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Submissions', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          child: answers.isEmpty
              ? const Center(
                  child: Text('No submissions yet.',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: answers.length,
                  itemBuilder: (context, index) {
                    final ans = answers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: ListTile(
                          title: Text('Question ID: ${ans['payload'].split('|')[1].substring(0, 8)}...',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Answer: ${ans['payload'].split('|')[2]}',
                              style: const TextStyle(color: Colors.white70)),
                          trailing: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
