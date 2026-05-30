import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'role_selection_screen.dart';
import '../widgets/glass_card.dart';

enum AppMode { classroom, exam }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
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

  void _navigateToRoleSelection(AppMode mode) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => RoleSelectionScreen(mode: mode),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AetherNet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                      Color(0xFF3B0764),
                      Color(0xFF0F172A),
                    ],
                    stops: [0.0, _bgController.value, 1.0],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
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
                      'Choose Mode',
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
                      'Select the module you want to launch',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                    const SizedBox(height: 48),

                    // Classroom Mode Card
                    GestureDetector(
                      onTap: () => _navigateToRoleSelection(AppMode.classroom),
                      child: GlassCard(
                        color: const Color(0x339333EA), // Purple accent
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0x669333EA),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.co_present_rounded, size: 48, color: Colors.purpleAccent),
                              ),
                              const SizedBox(width: 24),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Classroom Mode', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                    SizedBox(height: 8),
                                    Text('Interactive mesh classroom with chat, whiteboard, and polls', style: TextStyle(color: Colors.white70, height: 1.3)),
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
                    
                    // Exam Mode Card
                    GestureDetector(
                      onTap: () => _navigateToRoleSelection(AppMode.exam),
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
                                child: const Icon(Icons.assignment_rounded, size: 48, color: Colors.blueAccent),
                              ),
                              const SizedBox(width: 24),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Exam Mode', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                    SizedBox(height: 8),
                                    Text('Secure offline exam environment with proctoring', style: TextStyle(color: Colors.white70, height: 1.3)),
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
