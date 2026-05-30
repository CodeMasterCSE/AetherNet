import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../sync/sync_engine.dart';
import '../../widgets/glass_card.dart';
import '../network_visualizer.dart';
import 'question_bank_screen.dart';
import '../../network/discovery_service.dart';
import '../../storage/local_storage.dart';
import '../../mesh/mesh_router.dart';
import '../../utils/pdf_generator.dart';

class CreateExamScreen extends ConsumerStatefulWidget {
  const CreateExamScreen({super.key});

  @override
  ConsumerState<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends ConsumerState<CreateExamScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  QuestionType _selectedType = QuestionType.scq;
  Set<int> _correctOptionIndices = {};
  final TextEditingController _marksController = TextEditingController(text: '1');
  final TextEditingController _durationController = TextEditingController(text: '30');
  final Map<String, Map<String, int>> _manualMarks = {}; // studentId_qId -> marks
  bool _examStarted = false;

  @override
  void initState() {
    super.initState();
    _checkAndStartSession();
  }

  Future<void> _checkAndStartSession() async {
    final nearbyService = ref.read(nearbyServiceProvider);
    final mesh = ref.read(meshProvider);

    // 1. Stop everything first
    await nearbyService.stopAll();
    await LocalStorage.clearSessionData(); // Fresh start for new session
    ref.read(syncProvider).reset(); // Clear in-memory state

    // 2. Start temporary discovery to check for existing teacher
    bool conflictDetected = false;
    await nearbyService.startDiscovery(
      LocalStorage.userName,
      (id, name, serviceId) {
        final parts = name.split('|');
        if (parts.length >= 3) {
          final existingPaper = parts[1];
          final existingCode = parts[2];
          if (existingPaper == LocalStorage.paperName && existingCode == LocalStorage.examCode) {
            conflictDetected = true;
            nearbyService.stopDiscovery();
            _showConflictDialog();
          }
        }
      },
      (id) {},
    );

    // 3. Wait a bit for discovery to find peers
    await Future.delayed(const Duration(seconds: 3));
    
    if (!conflictDetected) {
      await nearbyService.stopDiscovery();
      final advertName = '${LocalStorage.userName}|${LocalStorage.paperName}|${LocalStorage.examCode}';
      nearbyService.startAdvertising(
        advertName,
        mesh.handleConnectionInitiated,
        mesh.handleConnectionResult,
        mesh.handleDisconnected,
      );
    }
  }

  void _showConflictDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 12),
            Text('Session Conflict', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'A teacher is already hosting an exam for "${LocalStorage.paperName}" (Code: ${LocalStorage.examCode}).\n\nOnly one teacher is allowed per session.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _marksController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    final mesh = ref.watch(meshProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${LocalStorage.paperName} Dashboard', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            icon: const Icon(Icons.library_books_rounded, color: Colors.cyanAccent),
            tooltip: 'Question Bank',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionBankScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.hub_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkVisualizerScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
            onPressed: () => _showEndSessionDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GlassCard(
            color: _examStarted ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.amberAccent.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_examStarted ? 'Exam in Progress' : 'Set Exam Duration', 
                          style: TextStyle(color: _examStarted ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold)),
                        if (!_examStarted)
                          const Text('Students can only see questions after you start.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        if (_examStarted && ref.watch(meshProvider).examEndTime != null)
                          StreamBuilder(
                            stream: Stream.periodic(const Duration(seconds: 1)),
                            builder: (context, _) {
                              final mesh = ref.read(meshProvider);
                              final remaining = mesh.examEndTime!.difference(DateTime.now());
                              if (remaining.isNegative) return const Text('Time Up!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold));
                              final mins = remaining.inMinutes;
                              final secs = remaining.inSeconds % 60;
                              return Text('Time Remaining: ${mins}m ${secs}s', 
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
                            },
                          ),
                      ],
                    ),
                  ),
                  if (!_examStarted)
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Mins',
                          labelText: 'Mins',
                          labelStyle: const TextStyle(color: Colors.white30, fontSize: 10),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _examStarted ? null : () {
                      final mesh = ref.read(meshProvider);
                      final duration = int.tryParse(_durationController.text) ?? 30;
                      mesh.broadcast('EXAM_START', json.encode({'duration': duration}));
                      setState(() {
                        _examStarted = true;
                        mesh.examEndTime = DateTime.now().add(Duration(minutes: duration));
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _examStarted ? Colors.white10 : Colors.greenAccent,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(_examStarted ? 'Started' : 'Start Exam'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  SegmentedButton<QuestionType>(
                    segments: const [
                      ButtonSegment(value: QuestionType.scq, label: Text('Single'), icon: Icon(Icons.radio_button_checked)),
                      ButtonSegment(value: QuestionType.mcq, label: Text('Multi'), icon: Icon(Icons.check_box)),
                      ButtonSegment(value: QuestionType.paragraph, label: Text('Para'), icon: Icon(Icons.notes)),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (newSelection) {
                      setState(() => _selectedType = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _questionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Type your question here...',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (_selectedType != QuestionType.paragraph) ...[
                    const SizedBox(height: 16),
                    for (int i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_selectedType == QuestionType.scq) {
                                  _correctOptionIndices = {i};
                                } else {
                                  if (_correctOptionIndices.contains(i)) {
                                    _correctOptionIndices.remove(i);
                                  } else {
                                    _correctOptionIndices.add(i);
                                  }
                                }
                              });
                            },
                            child: Container(
                              width: 32, height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _correctOptionIndices.contains(i) ? Colors.greenAccent : Colors.white.withValues(alpha: 0.05),
                                border: Border.all(color: _correctOptionIndices.contains(i) ? Colors.greenAccent : Colors.white24),
                              ),
                              child: _correctOptionIndices.contains(i)
                                  ? const Icon(Icons.check, color: Colors.black, size: 18)
                                  : Center(child: Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white38, fontSize: 12))),
                            ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[i],
                                decoration: InputDecoration(
                                  hintText: 'Option ${String.fromCharCode(65 + i)}',
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Tap circle to mark correct answer', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _marksController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Marks for this question',
                        prefixIcon: const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Publish to Mesh', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (_questionController.text.isNotEmpty) {
                        final options = _selectedType == QuestionType.paragraph
                            ? <String>[]
                            : _optionControllers.map((e) => e.text).where((t) => t.isNotEmpty).toList();

                        String? correctAns;
                        if (_selectedType != QuestionType.paragraph && _correctOptionIndices.isNotEmpty) {
                          correctAns = _correctOptionIndices
                              .where((i) => i < options.length)
                              .map((i) => options[i])
                              .join(',');
                        }

                        sync.publishQuestion(Question(
                          id: const Uuid().v4(),
                          text: _questionController.text,
                          options: options,
                          type: _selectedType,
                          correctAnswer: correctAns,
                          marks: int.tryParse(_marksController.text) ?? 1,
                        ));

                        _questionController.clear();
                        for (var c in _optionControllers) {
                          c.clear();
                        }
                        _correctOptionIndices = {};
                        _marksController.text = '1';
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'PUBLISHED QUESTIONS',
            style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          ...sync.activeQuestions.map((q) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.white.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(
                q.type == QuestionType.paragraph ? Icons.notes : Icons.quiz_outlined,
                color: q.type == QuestionType.paragraph ? Colors.purpleAccent : Colors.blueAccent,
              ),
              title: Text(q.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: Text(
                '${q.marks} marks  •  Responses: ${sync.studentAnswers.keys.where((k) => k.endsWith(q.id)).length}'
                '${q.correctAnswer != null ? "  •  Key: ${q.correctAnswer}" : ""}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          )),
          if (sync.activeQuestions.isNotEmpty && sync.studentAnswers.isNotEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.grading_rounded),
              label: const Text('Auto-Grade Results', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showGradingResults(sync),
            ),
          ],
        ],
      ),
    );
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

  void _showEndSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('End Session?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will disconnect all students, wipe local exam data, and stop the mesh. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('End & Wipe', style: TextStyle(color: Colors.white)),
            onPressed: () {
              ref.read(meshProvider).endSession();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  void _showGradingResults(SyncEngine sync) {
    final mesh = ref.read(meshProvider);
    final studentIds = <String>{};
    for (final key in sync.studentAnswers.keys) {
      final idx = key.indexOf('_');
      if (idx > 0) studentIds.add(key.substring(0, idx));
    }

    final allQuestions = sync.activeQuestions;
    final totalMarks = allQuestions.fold<int>(0, (sum, q) => sum + q.marks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.grading_rounded, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    Text('Evaluation  •  Total: $totalMarks marks',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => PdfGenerator.generatePerformanceReport(
                        paperName: LocalStorage.paperName,
                        examCode: LocalStorage.examCode,
                        questions: allQuestions,
                        studentAnswers: sync.studentAnswers,
                        manualMarks: _manualMarks,
                        nodeNames: mesh.nodeNames,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.cyanAccent, size: 18),
                      label: const Text('PDF', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 0),
              if (studentIds.isEmpty)
                const Expanded(child: Center(child: Text('No responses yet.', style: TextStyle(color: Colors.white38))))
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: studentIds.length,
                    itemBuilder: (context, index) {
                      final studentId = studentIds.elementAt(index);
                      int scored = 0;

                      // Auto-grade MCQ/SCQ
                      for (final q in allQuestions) {
                        if (q.type != QuestionType.paragraph && q.correctAnswer != null) {
                          final answer = sync.studentAnswers['${studentId}_${q.id}'];
                          if (answer != null) {
                            final studentAnsSet = answer.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
                            final correctAnsSet = q.correctAnswer!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
                            if (studentAnsSet.length == correctAnsSet.length && studentAnsSet.containsAll(correctAnsSet)) {
                              scored += q.marks;
                            }
                          }
                        } else if (q.type == QuestionType.paragraph) {
                          scored += _manualMarks['${studentId}_${q.id}']?['marks'] ?? 0;
                        }
                      }

                      final percentage = totalMarks > 0 ? ((scored / totalMarks) * 100).round() : 0;
                      final color = percentage >= 70 ? Colors.greenAccent : (percentage >= 40 ? Colors.orangeAccent : Colors.redAccent);

                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Text('$percentage%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                             title: Builder(
                               builder: (context) {
                                 final identity = mesh.nodeNames[studentId] ?? 'Unknown|???';
                                 final parts = identity.split('|');
                                 final name = parts[0];
                                 final roll = parts.length > 1 ? parts[1] : '???';
                                 return Text('$name (Roll: $roll)', 
                                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15));
                               },
                             ),
                            subtitle: Text('$scored / $totalMarks marks', style: TextStyle(color: color, fontSize: 13)),
                            children: allQuestions.map((q) {
                              final answer = sync.studentAnswers['${studentId}_${q.id}'];
                              final isAutoCorrect = q.type != QuestionType.paragraph && q.correctAnswer != null;
                              bool isCorrect = false;
                              if (isAutoCorrect && answer != null) {
                                final studentAnsSet = answer.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
                                final correctAnsSet = q.correctAnswer!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
                                isCorrect = studentAnsSet.length == correctAnsSet.length && studentAnsSet.containsAll(correctAnsSet);
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(q.text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                        Text('${q.marks}m', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Answer: ${answer ?? "Not answered"}',
                                        style: TextStyle(color: answer != null ? Colors.white54 : Colors.redAccent, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    if (isAutoCorrect)
                                      Row(
                                        children: [
                                          Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                                              color: isCorrect ? Colors.greenAccent : Colors.redAccent, size: 20),
                                          const SizedBox(width: 8),
                                          Text(isCorrect ? '✓ Correct (+${q.marks})' : '✗ Wrong (Key: ${q.correctAnswer})',
                                              style: TextStyle(color: isCorrect ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      )
                                    else if (q.type == QuestionType.paragraph)
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
                                            tooltip: 'Award full marks',
                                            onPressed: () => setSheetState(() {
                                              _manualMarks['${studentId}_${q.id}'] = {'marks': q.marks};
                                            }),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 22),
                                            tooltip: 'Award zero marks',
                                            onPressed: () => setSheetState(() {
                                              _manualMarks['${studentId}_${q.id}'] = {'marks': 0};
                                            }),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 60,
                                            child: TextField(
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                hintText: '/${q.marks}',
                                                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                                                filled: true,
                                                fillColor: Colors.white.withValues(alpha: 0.05),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                              ),
                                              onChanged: (val) => setSheetState(() {
                                                final m = int.tryParse(val) ?? 0;
                                                _manualMarks['${studentId}_${q.id}'] = {'marks': m.clamp(0, q.marks)};
                                              }),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${_manualMarks['${studentId}_${q.id}']?['marks'] ?? 0}/${q.marks}',
                                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
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
}
