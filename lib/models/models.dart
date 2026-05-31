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

// Classroom Mode Models

class Classroom {
  final String id;
  final String name;
  final String teacherId;
  final List<String> enrolledStudentIds;
  final DateTime createdAt;

  Classroom({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.enrolledStudentIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacherId': teacherId,
    'enrolledStudentIds': enrolledStudentIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Classroom.fromJson(Map<String, dynamic> json) => Classroom(
    id: json['id'],
    name: json['name'],
    teacherId: json['teacherId'],
    enrolledStudentIds: List<String>.from(json['enrolledStudentIds'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class ChatMessage {
  final String id;
  final String senderName;
  final String text;
  final DateTime timestamp;

  ChatMessage({required this.id, required this.senderName, required this.text, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderName': senderName,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    senderName: json['senderName'],
    text: json['text'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class WhiteboardPoint {
  final double x;
  final double y;
  WhiteboardPoint(this.x, this.y);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory WhiteboardPoint.fromJson(Map<String, dynamic> json) => WhiteboardPoint(json['x'].toDouble(), json['y'].toDouble());
}

class WhiteboardStroke {
  final List<WhiteboardPoint> points;
  final int colorValue;
  final double strokeWidth;

  WhiteboardStroke({required this.points, required this.colorValue, required this.strokeWidth});

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => p.toJson()).toList(),
    'colorValue': colorValue,
    'strokeWidth': strokeWidth,
  };

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) => WhiteboardStroke(
    points: (json['points'] as List).map((p) => WhiteboardPoint.fromJson(p)).toList(),
    colorValue: json['colorValue'],
    strokeWidth: json['strokeWidth'].toDouble(),
  );
}

class Poll {
  final String id;
  final String question;
  final List<String> options;

  Poll({required this.id, required this.question, required this.options});

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options,
  };

  factory Poll.fromJson(Map<String, dynamic> json) => Poll(
    id: json['id'],
    question: json['question'],
    options: List<String>.from(json['options']),
  );
}

class Assignment {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;

  Assignment({required this.id, required this.title, required this.description, required this.dueDate});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'dueDate': dueDate.toIso8601String(),
  };

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    dueDate: DateTime.parse(json['dueDate']),
  );
}

class SubmissionEntity {
  final String id;
  final String studentId;
  final String studentName;
  final String examId;
  final Map<String, String> answers;
  final double? score;
  final double? totalMarks;
  final int suspicionScore;
  final DateTime submittedAt;

  SubmissionEntity({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.examId,
    required this.answers,
    this.score,
    this.totalMarks,
    required this.suspicionScore,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'examId': examId,
    'answers': answers,
    'score': score,
    'totalMarks': totalMarks,
    'suspicionScore': suspicionScore,
    'submittedAt': submittedAt.toIso8601String(),
  };

  factory SubmissionEntity.fromJson(Map<String, dynamic> json) => SubmissionEntity(
    id: json['id'],
    studentId: json['studentId'],
    studentName: json['studentName'] ?? 'Unknown',
    examId: json['examId'],
    answers: Map<String, String>.from(json['answers'] ?? {}),
    score: json['score'] != null ? (json['score'] as num).toDouble() : null,
    totalMarks: json['totalMarks'] != null ? (json['totalMarks'] as num).toDouble() : null,
    suspicionScore: json['suspicionScore'] ?? 0,
    submittedAt: DateTime.parse(json['submittedAt']),
  );
}

