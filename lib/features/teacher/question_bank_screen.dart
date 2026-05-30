import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../storage/local_storage.dart';
import '../../sync/sync_engine.dart';
import '../../widgets/glass_card.dart';

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  List<PaperTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    setState(() {
      _templates = LocalStorage.getAllTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
            onPressed: () => _showCreateTemplateDialog(context),
          ),
        ],
      ),
      body: _templates.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_books_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 20),
                  const Text('No Saved Templates', style: TextStyle(color: Colors.white38, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Create one from the + button or save from an exam session.',
                      style: TextStyle(color: Colors.white24, fontSize: 13), textAlign: TextAlign.center),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return _buildTemplateCard(template);
              },
            ),
    );
  }

  Widget _buildTemplateCard(PaperTemplate template) {
    final mcqCount = template.questions.where((q) => q.type == QuestionType.mcq).length;
    final scqCount = template.questions.where((q) => q.type == QuestionType.scq).length;
    final paraCount = template.questions.where((q) => q.type == QuestionType.paragraph).length;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (template.subject.isNotEmpty)
                        Text(template.subject, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  color: const Color(0xFF1E293B),
                  onSelected: (value) {
                    if (value == 'delete') _deleteTemplate(template);
                    if (value == 'preview') _previewTemplate(template);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'preview', child: Text('Preview Questions', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildBadge('${template.questions.length} Qs', Colors.blueAccent),
                if (scqCount > 0) _buildBadge('$scqCount SCQ', Colors.cyan),
                if (mcqCount > 0) _buildBadge('$mcqCount MCQ', Colors.orangeAccent),
                if (paraCount > 0) _buildBadge('$paraCount Para', Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Created: ${template.createdAt.day}/${template.createdAt.month}/${template.createdAt.year}',
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Load into Exam'),
                onPressed: () => _loadTemplateIntoExam(template),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _loadTemplateIntoExam(PaperTemplate template) {
    final sync = ref.read(syncProvider);
    for (final q in template.questions) {
      sync.publishQuestion(Question(
        id: const Uuid().v4(),
        text: q.text,
        options: q.options,
        type: q.type,
        correctAnswer: q.correctAnswer,
      ));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Loaded ${template.questions.length} questions from "${template.name}"'),
        backgroundColor: Colors.green.shade800,
      ),
    );
    Navigator.pop(context);
  }

  void _deleteTemplate(PaperTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Template?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${template.name}"? This cannot be undone.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              await LocalStorage.deleteTemplate(template.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadTemplates();
            },
          ),
        ],
      ),
    );
  }

  void _previewTemplate(PaperTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.preview_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 0),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: template.questions.length,
                itemBuilder: (context, index) {
                  final q = template.questions[index];
                  return Card(
                    color: Colors.white.withValues(alpha: 0.05),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildBadge(q.type.name.toUpperCase(), _getTypeColor(q.type)),
                              Text('Q${index + 1}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(q.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                          if (q.options.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...q.options.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('  ${String.fromCharCode(65 + e.key)}) ${e.value}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            )),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(QuestionType type) {
    switch (type) {
      case QuestionType.mcq: return Colors.orangeAccent;
      case QuestionType.scq: return Colors.cyan;
      case QuestionType.paragraph: return Colors.purpleAccent;
    }
  }

  void _showCreateTemplateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final List<_DraftQuestion> draftQuestions = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('New Paper Template', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Template Name (e.g. Mid-Term Math)',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Subject (optional)',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...draftQuestions.asMap().entries.map((entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildBadge(entry.value.type.name.toUpperCase(), _getTypeColor(entry.value.type)),
                        Expanded(child: Text(entry.value.text, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                          onPressed: () => setDialogState(() => draftQuestions.removeAt(entry.key)),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Question'),
                    onPressed: () => _showAddQuestionDialog(context, draftQuestions, setDialogState),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              child: const Text('Save Template'),
              onPressed: () async {
                if (nameController.text.isEmpty || draftQuestions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and at least one question are required.'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                final template = PaperTemplate(
                  id: const Uuid().v4(),
                  name: nameController.text,
                  subject: subjectController.text,
                  questions: draftQuestions.map((d) => Question(
                    id: const Uuid().v4(),
                    text: d.text,
                    options: d.options,
                    type: d.type,
                    correctAnswer: d.correctAnswer,
                    marks: d.marks,
                  )).toList(),
                  createdAt: DateTime.now(),
                );
                await LocalStorage.saveTemplate(template);
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadTemplates();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionDialog(BuildContext parentContext, List<_DraftQuestion> draftQuestions, StateSetter setParentState) {
    final qController = TextEditingController();
    final optControllers = [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()];
    final marksController = TextEditingController(text: '1');
    QuestionType selectedType = QuestionType.scq;
    Set<int> correctOptionIndices = {};

    showDialog(
      context: parentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setQState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Add Question', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<QuestionType>(
                  segments: const [
                    ButtonSegment(value: QuestionType.scq, label: Text('SCQ')),
                    ButtonSegment(value: QuestionType.mcq, label: Text('MCQ')),
                    ButtonSegment(value: QuestionType.paragraph, label: Text('Para')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (s) => setQState(() => selectedType = s.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Question text...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                if (selectedType != QuestionType.paragraph) ...[
                  const SizedBox(height: 12),
                  for (int i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setQState(() {
                              if (selectedType == QuestionType.scq) {
                                correctOptionIndices = {i};
                              } else {
                                if (correctOptionIndices.contains(i)) {
                                  correctOptionIndices.remove(i);
                                } else {
                                  correctOptionIndices.add(i);
                                }
                              }
                            }),
                            child: Container(
                              width: 28, height: 28,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: correctOptionIndices.contains(i) ? Colors.greenAccent : Colors.white10,
                                border: Border.all(color: correctOptionIndices.contains(i) ? Colors.greenAccent : Colors.white24),
                              ),
                              child: correctOptionIndices.contains(i)
                                  ? const Icon(Icons.check, color: Colors.black, size: 16)
                                  : Center(child: Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white24, fontSize: 10))),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: optControllers[i],
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Option ${String.fromCharCode(65 + i)}',
                                hintStyle: const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.03),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text('Tap circle to mark correct answer', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: marksController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Marks',
                    prefixIcon: const Icon(Icons.star, color: Colors.amberAccent, size: 18),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                if (qController.text.isEmpty) return;
                final opts = selectedType == QuestionType.paragraph
                    ? <String>[]
                    : optControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
                
                String? correctAns;
                if (selectedType != QuestionType.paragraph && correctOptionIndices.isNotEmpty) {
                  correctAns = correctOptionIndices
                      .where((i) => i < opts.length)
                      .map((i) => opts[i])
                      .join(',');
                }

                setParentState(() {
                  draftQuestions.add(_DraftQuestion(
                    text: qController.text,
                    type: selectedType,
                    options: opts,
                    correctAnswer: correctAns,
                    marks: int.tryParse(marksController.text) ?? 1,
                  ));
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftQuestion {
  final String text;
  final QuestionType type;
  final List<String> options;
  final String? correctAnswer;
  final int marks;

  _DraftQuestion({
    required this.text,
    required this.type,
    required this.options,
    this.correctAnswer,
    this.marks = 1,
  });
}
