import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/models.dart';
import '../../storage/local_storage.dart';
import '../../widgets/glass_card.dart';
import 'classroom_teacher_dashboard.dart';
import 'package:uuid/uuid.dart';

class ClassroomSelectionScreen extends StatefulWidget {
  const ClassroomSelectionScreen({super.key});

  @override
  State<ClassroomSelectionScreen> createState() => _ClassroomSelectionScreenState();
}

class _ClassroomSelectionScreenState extends State<ClassroomSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  List<Classroom> _classrooms = [];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _loadClassrooms();
  }

  void _loadClassrooms() {
    setState(() {
      _classrooms = LocalStorage.getAllClassrooms();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _createNewClassroom() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('New Classroom', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter classroom name',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final classroom = Classroom(
        id: const Uuid().v4(),
        name: result,
        teacherId: LocalStorage.deviceId,
        enrolledStudentIds: [],
        createdAt: DateTime.now(),
      );
      await LocalStorage.saveClassroom(classroom);
      _loadClassrooms();
    }
  }

  void _deleteClassroom(Classroom classroom) async {
    await LocalStorage.deleteClassroom(classroom.id);
    _loadClassrooms();
  }

  void _openClassroom(Classroom classroom) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassroomTeacherDashboard(classroom: classroom)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Classrooms', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                    stops: [0.0, _bgController.value, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _classrooms.isEmpty
                      ? Center(
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school_outlined, size: 64, color: Colors.white38),
                              SizedBox(height: 16),
                              Text('No classrooms found.', style: TextStyle(color: Colors.white54, fontSize: 18)),
                            ],
                          ).animate().fadeIn(),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classrooms.length,
                          itemBuilder: (context, index) {
                            final cls = _classrooms[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: GestureDetector(
                                onTap: () => _openClassroom(cls),
                                child: GlassCard(
                                  color: const Color(0x1A3B82F6),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.blueAccent,
                                      child: Icon(Icons.co_present, color: Colors.white),
                                    ),
                                    title: Text(cls.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    subtitle: Text('${cls.enrolledStudentIds.length} Students', style: const TextStyle(color: Colors.white70)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _deleteClassroom(cls),
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.1, end: 0),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton.icon(
                    onPressed: _createNewClassroom,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Classroom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
