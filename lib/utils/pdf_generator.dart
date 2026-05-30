import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfGenerator {
  static Future<void> generatePerformanceReport({
    required String paperName,
    required String examCode,
    required List<Question> questions,
    required Map<String, String> studentAnswers,
    required Map<String, Map<String, int>> manualMarks,
    required Map<String, String> nodeNames,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    
    // Calculate totals
    final totalPossibleMarks = questions.fold<int>(0, (sum, q) => sum + q.marks);
    
    // Aggregating student data
    final studentIds = <String>{};
    for (final key in studentAnswers.keys) {
      if (key.contains('_')) {
        studentIds.add(key.split('_')[0]);
      }
    }

    final List<Map<String, dynamic>> results = [];
    for (final sid in studentIds) {
      int scored = 0;
      for (final q in questions) {
        if (q.type != QuestionType.paragraph && q.correctAnswer != null) {
          final ans = studentAnswers['${sid}_${q.id}'];
          if (ans != null) {
            final sSet = ans.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
            final cSet = q.correctAnswer!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
            if (sSet.length == cSet.length && sSet.containsAll(cSet)) {
              scored += q.marks;
            }
          }
        } else if (q.type == QuestionType.paragraph) {
          scored += manualMarks['${sid}_${q.id}']?['marks'] ?? 0;
        }
      }
      final percent = totalPossibleMarks > 0 ? (scored / totalPossibleMarks * 100).round() : 0;
      
      final identity = nodeNames[sid] ?? 'Unknown|???';
      final parts = identity.split('|');
      final name = parts[0];
      final roll = parts.length > 1 ? parts[1] : '???';

      results.add({
        'name': name,
        'roll': roll,
        'scored': scored,
        'percent': percent,
      });
    }

    // Sort by marks desc
    results.sort((a, b) => b['scored'].compareTo(a['scored']));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MeshExam Performance Report', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                pw.Text(now, style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Exam: $paperName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Code: $examCode'),
                  pw.Text('Total Questions: ${questions.length}'),
                  pw.Text('Total Marks: $totalPossibleMarks'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Rank', 'Student Name', 'Roll No', 'Marks Scored', 'Percentage'],
            data: List<List<String>>.generate(results.length, (index) {
              final r = results[index];
              return [
                '${index + 1}',
                r['name'],
                r['roll'],
                '${r['scored']} / $totalPossibleMarks',
                '${r['percent']}%',
              ];
            }),
          ),
          pw.Footer(
            trailing: pw.Text('Generated via MeshExam decentralized engine'),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Report_${paperName.replaceAll(' ', '_')}.pdf',
    );
  }
}
