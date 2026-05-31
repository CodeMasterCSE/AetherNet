import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/sync_engine.dart';
import '../../widgets/glass_card.dart';
import '../network_visualizer.dart';
import '../../mesh/mesh_router.dart';
import '../../models/models.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import '../../storage/local_storage.dart';
import 'dart:math';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ExamTakingScreen extends ConsumerStatefulWidget {
  const ExamTakingScreen({super.key});

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen> with WidgetsBindingObserver {
  bool _isSubmitted = false;
  int _backgroundOffenses = 0;
  static const _anticheatChannel = MethodChannel('meshexam/anticheat');

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isDetecting = false;
  DateTime _lastDetectionTime = DateTime.now();
  int _faceOffenses = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableAntiCheat();
    _initCameraAndFaceDetection();
  }

  Future<void> _initCameraAndFaceDetection() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          enableClassification: false,
          enableTracking: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      _cameraController!.startImageStream((CameraImage image) async {
        if (_isDetecting || _isSubmitted) return;
        final now = DateTime.now();
        if (now.difference(_lastDetectionTime).inSeconds < 3) return; // Process every 3 seconds
        
        _isDetecting = true;
        _lastDetectionTime = now;

        try {
          final WriteBuffer allBytes = WriteBuffer();
          for (final Plane plane in image.planes) {
            allBytes.putUint8List(plane.bytes);
          }
          final bytes = allBytes.done().buffer.asUint8List();

          final metadata = InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotationValue.fromRawValue(frontCamera.sensorOrientation) ?? InputImageRotation.rotation0deg,
            format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          );

          final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
          final faces = await _faceDetector!.processImage(inputImage);

          if (faces.isEmpty) {
            _logFaceViolation('No face detected in camera frame.');
          } else if (faces.length > 1) {
            _logFaceViolation('Multiple faces detected (${faces.length}) in camera frame.');
          }
        } catch (e) {
          debugPrint('Face detection error: $e');
        } finally {
          _isDetecting = false;
        }
      });
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _logFaceViolation(String reason) {
    if (_isSubmitted || !mounted) return;
    _faceOffenses++;
    final sync = ref.read(syncProvider);
    final currentLogs = sync.suspicionReports[LocalStorage.deviceId]?.offenseLogs ?? [];
    
    // Add 10 suspicion points per face offense
    sync.sendSuspicionUpdate(
      _backgroundOffenses, 
      _faceOffenses,
      [...currentLogs, '$reason at ${DateTime.now().toIso8601String()}']
    );
  }

  Future<void> _enableAntiCheat() async {
    try {
      await startKioskMode();
      await _anticheatChannel.invokeMethod('setSecureFlag');
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      debugPrint('Failed to enable anti-cheat: $e');
    }
  }

  Future<void> _disableAntiCheat() async {
    try {
      await stopKioskMode();
      await _anticheatChannel.invokeMethod('clearSecureFlag');
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      debugPrint('Failed to disable anti-cheat: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableAntiCheat();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isSubmitted) return;
    
    if (state == AppLifecycleState.paused) {
      // User sent app to background
      _backgroundOffenses++;
      final sync = ref.read(syncProvider);
      final currentLogs = sync.suspicionReports[LocalStorage.deviceId]?.offenseLogs ?? [];
      sync.sendSuspicionUpdate(
        _backgroundOffenses, 
        _faceOffenses,
        [...currentLogs, 'App sent to background at ${DateTime.now().toIso8601String()}']
      );
    } else if (state == AppLifecycleState.resumed && _backgroundOffenses > 0) {
      _showWarningDialog();
    }
  }

  void _showWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('WARNING LOGGED', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'You have navigated away from the exam screen.\n\nThis is a violation of exam rules. Your suspicion score has been updated to ${_backgroundOffenses * 30} and the teacher has been notified.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // terminateAndSubmit removed as per phase 3 score update rules

  List<Question> _getShuffledQuestions(List<Question> original) {
    final r = Random(LocalStorage.deviceId.hashCode);
    final copy = List<Question>.from(original);
    copy.shuffle(r);
    return copy;
  }

  List<String> _getShuffledOptions(Question q) {
    final r = Random(LocalStorage.deviceId.hashCode ^ q.id.hashCode);
    final copy = List<String>.from(q.options);
    copy.shuffle(r);
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    final mesh = ref.watch(meshProvider);
    
    // Listen for session end
    ref.listen(meshProvider, (previous, next) {
      if (!next.isSessionActive) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });

    final hasStarted = mesh.examEndTime != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Exam'),
        bottom: hasStarted ? PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, _) {
              final remaining = mesh.examEndTime!.difference(DateTime.now());
              if (remaining.isNegative) {
                if (!_isSubmitted) {
                  _isSubmitted = true;
                  Future.microtask(() {
                    sync.submitFinalExam();
                    if (!context.mounted) return;
                    _showSuccessAndExit(context);
                  });
                }
                return Container(
                  width: double.infinity,
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Text('TIME UP! SUBMITTING...', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                );
              }
              final mins = remaining.inMinutes;
              final secs = remaining.inSeconds % 60;
              return Container(
                width: double.infinity,
                color: Colors.amberAccent.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Time Remaining: ${mins}m ${secs}s', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              );
            },
          ),
        ) : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.hub),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkVisualizerScreen()));
            },
          )
        ],
      ),
      body: !hasStarted 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 64, color: Colors.amberAccent),
                  const SizedBox(height: 20),
                  const Text('Waiting for teacher to start...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Joined: ${LocalStorage.paperName}', style: const TextStyle(color: Colors.white38)),
                ],
              ),
            )
          : sync.activeQuestions.isEmpty
              ? const Center(child: Text('Waiting for questions to sync...', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sync.activeQuestions.length,
                  itemBuilder: (context, index) {
                    final shuffledQs = _getShuffledQuestions(sync.activeQuestions);
                    final q = shuffledQs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(q.type).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      q.type.name.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getTypeColor(q.type)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Question ${index + 1}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(q.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 20),
                              _buildInputForType(context, sync, q),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: !hasStarted || sync.activeQuestions.isEmpty || _isSubmitted
          ? null
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('FINAL SUBMIT EXAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () => _showSubmitConfirmation(context, sync),
              ),
            ),
    );
  }

  void _showSubmitConfirmation(BuildContext context, SyncEngine sync) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Submit Exam?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Once submitted, you cannot change your answers. Do you want to proceed?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Review Again'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text('Yes, Submit', style: TextStyle(color: Colors.black)),
            onPressed: () {
              setState(() => _isSubmitted = true);
              sync.submitFinalExam();
              Navigator.pop(context); // Close dialog
              _showSuccessAndExit(context);
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessAndExit(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 60),
            const SizedBox(height: 20),
            const Text('Exam Submitted!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Your response has been securely synchronized with the teacher.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(QuestionType type) {
    switch (type) {
      case QuestionType.mcq: return Colors.orangeAccent;
      case QuestionType.scq: return Colors.blueAccent;
      case QuestionType.paragraph: return Colors.purpleAccent;
    }
  }

  Widget _buildInputForType(BuildContext context, SyncEngine sync, Question q) {
    if (_isSubmitted) {
      final answer = sync.studentAnswers['${LocalStorage.deviceId}_${q.id}'] ?? 'No answer';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Your Answer: $answer', style: const TextStyle(color: Colors.white70)),
      );
    }

    switch (q.type) {
      case QuestionType.scq:
        final currentValue = sync.studentAnswers['${LocalStorage.deviceId}_${q.id}'] ?? '';
        final shuffledOptions = _getShuffledOptions(q);
        return Column(
          children: shuffledOptions.map((option) {
            final isSelected = currentValue == option;
            return InkWell(
              onTap: () {
                if (option.isNotEmpty) {
                  sync.submitAnswer(q.id, option);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.blueAccent : Colors.white54,
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(option, style: const TextStyle(color: Colors.white70))),
                  ],
                ),
              ),
            );
          }).toList(),
        );

      case QuestionType.mcq:
        final selectedOptions = (sync.studentAnswers['${LocalStorage.deviceId}_${q.id}'] ?? '').split(',');
        final shuffledOptions = _getShuffledOptions(q);
        return Column(
          children: shuffledOptions.map((option) {
            final isSelected = selectedOptions.contains(option);
            return CheckboxListTile(
              title: Text(option, style: const TextStyle(color: Colors.white70)),
              value: isSelected,
              activeColor: Colors.orangeAccent,
              onChanged: (value) {
                var newSelection = List<String>.from(selectedOptions)..remove('');
                if (value == true) {
                  newSelection.add(option);
                } else {
                  newSelection.remove(option);
                }
                sync.submitAnswer(q.id, newSelection.join(','));
              },
            );
          }).toList(),
        );

      case QuestionType.paragraph:
        return TextField(
          maxLines: 4,
          enableInteractiveSelection: false, // Blocks copy/paste clipboard
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (value) => sync.submitAnswer(q.id, value),
        );
    }
  }
}
