import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../features/teacher/teacher_dashboard.dart';
import '../features/student/student_dashboard.dart';
import '../features/teacher/classroom_teacher_dashboard.dart';
import '../features/student/classroom_discovery_screen.dart';
import '../widgets/glass_card.dart';
import '../storage/local_storage.dart';
import 'home_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AppMode mode;
  const RoleSelectionScreen({super.key, required this.mode});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _showRegistrationDialog(bool isTeacher) async {
    final nameController = TextEditingController(text: LocalStorage.userName);
    final paperController = TextEditingController(text: LocalStorage.paperName);
    final codeController = TextEditingController(text: LocalStorage.examCode);
    final rollController = TextEditingController(text: LocalStorage.rollNumber);
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassCard(
          color: isTeacher ? const Color(0x333B82F6) : const Color(0x3310B981),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isTeacher ? 'Teacher Registration' : 'Student Registration',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: nameController,
                    label: isTeacher ? 'Teacher Name' : 'Student Name',
                    icon: Icons.person_outline,
                  ),
                  if (isTeacher) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: paperController,
                      label: widget.mode == AppMode.classroom ? 'Classroom Subject' : 'Paper Name',
                      icon: Icons.description_outlined,
                    ),
                    if (widget.mode == AppMode.exam) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: codeController,
                        label: 'Exam Code',
                        icon: Icons.code_rounded,
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: rollController,
                      label: 'Roll Number',
                      icon: Icons.numbers_rounded,
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        await LocalStorage.setIsTeacher(isTeacher);
                        await LocalStorage.setUserName(nameController.text);
                        if (isTeacher) {
                          await LocalStorage.setPaperName(paperController.text);
                          if (widget.mode == AppMode.exam) {
                            await LocalStorage.setExamCode(codeController.text);
                          } else {
                            await LocalStorage.setExamCode('CLASSROOM');
                          }
                        } else {
                          await LocalStorage.setRollNumber(rollController.text);
                        }
                        
                        if (!context.mounted) return;
                        Navigator.pop(context); // Close dialog
                        
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) {
                              if (widget.mode == AppMode.classroom) {
                                return isTeacher ? const ClassroomTeacherDashboard() : const ClassroomDiscoveryScreen();
                              } else {
                                return isTeacher ? const TeacherDashboard() : const StudentDashboard();
                              }
                            },
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTeacher ? Colors.blueAccent : Colors.greenAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white38),
        ),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.mode == AppMode.classroom ? 'Classroom Mode' : 'Exam Mode',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                    stops: [
                      0.0,
                      _bgController.value,
                      1.0,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select Your Role',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose how you want to connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                    const SizedBox(height: 48),

                    // Teacher Card
                    GestureDetector(
                      onTap: () => _showRegistrationDialog(true),
                      child: GlassCard(
                        color: const Color(0x1A3B82F6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0x333B82F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.school_rounded, size: 48, color: Colors.blueAccent),
                              ),
                              const SizedBox(width: 24),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Teacher', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                    SizedBox(height: 8),
                                    Text('Host exams & monitor students securely', style: TextStyle(color: Colors.white70, height: 1.3)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 24),
                    
                    // Student Card
                    GestureDetector(
                      onTap: () => _showRegistrationDialog(false),
                      child: GlassCard(
                        color: const Color(0x1A10B981),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0x3310B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded, size: 48, color: Colors.greenAccent),
                              ),
                              const SizedBox(width: 24),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Student', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                    SizedBox(height: 8),
                                    Text('Join a classroom & take offline exams', style: TextStyle(color: Colors.white70, height: 1.3)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
