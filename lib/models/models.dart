class DeviceNode {
  final String id;
  final String name;
  final bool isTeacher;
  final DateTime lastSeen;

  DeviceNode({
    required this.id,
    required this.name,
    this.isTeacher = false,
    required this.lastSeen,
  });
}

class MeshMessage {
  final String id;
  final String senderId;
  final String payload;
  final String signature;
  final int hopCount;
  final String type; // 'EXAM_CREATED', 'QUESTION_PUBLISHED', 'ANSWER_SUBMITTED'
  final DateTime timestamp;

  MeshMessage({
    required this.id,
    required this.senderId,
    required this.payload,
    required this.signature,
    required this.hopCount,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'payload': payload,
    'signature': signature,
    'hopCount': hopCount,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MeshMessage.fromJson(Map<String, dynamic> json) => MeshMessage(
    id: json['id'],
    senderId: json['senderId'],
    payload: json['payload'],
    signature: json['signature'],
    hopCount: json['hopCount'],
    type: json['type'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

enum QuestionType { mcq, scq, paragraph }

class Question {
  final String id;
  final String text;
  final List<String> options;
  final QuestionType type;
  final String? correctAnswer; // Teacher only
  final int marks;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.type,
    this.correctAnswer,
    this.marks = 1,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'options': options,
    'type': type.name,
    'correctAnswer': correctAnswer,
    'marks': marks,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'],
    text: json['text'],
    options: List<String>.from(json['options'] ?? []),
    type: QuestionType.values.byName(json['type'] ?? 'scq'),
    correctAnswer: json['correctAnswer'],
    marks: json['marks'] ?? 1,
  );
}

class PaperTemplate {
  final String id;
  final String name;
  final String subject;
  final List<Question> questions;
  final DateTime createdAt;

  PaperTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.questions,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subject': subject,
    'questions': questions.map((q) => q.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory PaperTemplate.fromJson(Map<String, dynamic> json) => PaperTemplate(
    id: json['id'],
    name: json['name'],
    subject: json['subject'] ?? '',
    questions: (json['questions'] as List).map((q) => Question.fromJson(Map<String, dynamic>.from(q))).toList(),
    createdAt: DateTime.parse(json['createdAt']),
  );
}
