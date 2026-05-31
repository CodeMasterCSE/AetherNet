

class SuspicionReport {
  final String studentId;
  final int backgroundOffenses;
  final int faceOffenses;
  final List<String> offenseLogs;
  final DateTime lastUpdated;

  SuspicionReport({
    required this.studentId,
    this.backgroundOffenses = 0,
    this.faceOffenses = 0,
    this.offenseLogs = const [],
    required this.lastUpdated,
  });

  // Calculate score 0-100
  // Background offense: +30 points each
  // Face offense: +10 points each
  int get score {
    int calculated = (backgroundOffenses * 30) + (faceOffenses * 10);
    if (calculated > 100) return 100;
    return calculated;
  }

  String get riskLevel {
    if (score <= 20) return 'Normal';
    if (score <= 50) return 'Moderate Risk';
    if (score <= 80) return 'High Risk';
    return 'Critical Risk';
  }

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'backgroundOffenses': backgroundOffenses,
    'faceOffenses': faceOffenses,
    'offenseLogs': offenseLogs,
    'lastUpdated': lastUpdated.toIso8601String(),
    'score': score,
    'riskLevel': riskLevel,
  };

  factory SuspicionReport.fromJson(Map<String, dynamic> json) => SuspicionReport(
    studentId: json['studentId'],
    backgroundOffenses: json['backgroundOffenses'] ?? 0,
    faceOffenses: json['faceOffenses'] ?? 0,
    offenseLogs: List<String>.from(json['offenseLogs'] ?? []),
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}
