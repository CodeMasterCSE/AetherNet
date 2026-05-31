import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mesh/mesh_router.dart';
import '../models/models.dart';
import '../storage/local_storage.dart';
import '../models/suspicion_score.dart';
import '../models/resource.dart';

import 'package:flutter/foundation.dart';

final syncProvider = ChangeNotifierProvider((ref) => SyncEngine(ref.read(meshProvider)));

class SyncEngine extends ChangeNotifier {
  final MeshRouter _router;

  // Exam Mode State
  List<Question> activeQuestions = [];
  Map<String, String> studentAnswers = {};
  Map<String, SubmissionEntity> examSubmissions = {}; // studentId -> SubmissionEntity

  // Classroom Mode State
  List<ChatMessage> chatMessages = [];
  List<WhiteboardStroke> whiteboardStrokes = [];
  List<Poll> activePolls = [];
  Map<String, Map<String, String>> pollResponses = {}; // pollId -> {studentId: option}
  List<Assignment> activeAssignments = [];
  Map<String, DateTime> attendance = {}; // studentId -> last seen
  Set<String> raisedHands = {}; // studentIds
  String? lastEmergencyAlert;
  Map<String, SuspicionReport> suspicionReports = {}; // studentId -> report
  List<SharedResource> sharedResources = [];

  SyncEngine(this._router) {
    _router.onMessageReceived = _handleMessage;
    _router.onEndSession = reset;
    // Defer state restoration so notifyListeners() doesn't fire
    // during ChangeNotifierProvider initialization, which would
    // cause an infinite rebuild loop.
    Future.microtask(_restoreState);
  }

  void _restoreState() {
    final messages = LocalStorage.getAllMessages();
    messages.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));
    
    for (var jsonMsg in messages) {
      _processEvent(MeshMessage.fromJson(jsonMsg));
    }
  }

  void _handleMessage(MeshMessage msg) {
    _processEvent(msg);
    notifyListeners();
  }

  void reset() {
    activeQuestions.clear();
    studentAnswers.clear();
    examSubmissions.clear();
    chatMessages.clear();
    whiteboardStrokes.clear();
    activePolls.clear();
    pollResponses.clear();
    activeAssignments.clear();
    attendance.clear();
    raisedHands.clear();
    lastEmergencyAlert = null;
    suspicionReports.clear();
    sharedResources.clear();
    notifyListeners();
  }

  void _processEvent(MeshMessage msg) {
    try {
      if (msg.type == 'END_SESSION') {
        reset();
        return;
      }

      final payload = json.decode(msg.payload);
      
      switch (msg.type) {
        // Exam Mode Events
        case 'QUESTION_PUBLISHED':
          final q = Question.fromJson(payload);
          if (!activeQuestions.any((element) => element.id == q.id)) {
            activeQuestions.add(q);
          }
          break;
        case 'ANSWER_SUBMITTED':
          studentAnswers['${payload['studentId']}_${payload['questionId']}'] = payload['answer'];
          break;
        case 'EXAM_SUBMITTED':
          final studentId = payload['studentId'];
          final studentName = payload['studentName'] ?? 'Unknown';
          
          final Map<String, dynamic> bulkAnswers = payload['answers'] ?? {};
          final Map<String, String> answers = {};
          
          double score = 0;
          double totalMarks = 0;

          bulkAnswers.forEach((qId, ans) {
            answers[qId] = ans.toString();
            studentAnswers['${studentId}_$qId'] = ans.toString();

            // Auto-evaluation logic
            try {
              final question = activeQuestions.firstWhere((q) => q.id == qId);
              if (question.correctAnswer != null && question.correctAnswer!.isNotEmpty) {
                totalMarks += question.marks;
                if (question.correctAnswer == ans.toString()) {
                  score += question.marks;
                }
              }
            } catch (e) {
              // Question not found in active list, ignore for evaluation
            }
          });

          final suspicionScore = suspicionReports[studentId]?.score ?? 0;

          examSubmissions[studentId] = SubmissionEntity(
            id: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
            studentId: studentId,
            studentName: studentName,
            examId: LocalStorage.examCode.isNotEmpty ? LocalStorage.examCode : 'CLASS_EXAM',
            answers: answers,
            score: score,
            totalMarks: totalMarks,
            suspicionScore: suspicionScore,
            submittedAt: DateTime.parse(payload['timestamp'] ?? DateTime.now().toIso8601String()),
          );
          break;
        case 'SUSPICION_UPDATE':
          final report = SuspicionReport.fromJson(payload);
          suspicionReports[report.studentId] = report;
          break;
        // Classroom Mode Events
        case 'CLASS_CHAT':
          chatMessages.add(ChatMessage.fromJson(payload));
          break;
        case 'WHITEBOARD_DATA':
          whiteboardStrokes.add(WhiteboardStroke.fromJson(payload));
          break;
        case 'WHITEBOARD_CLEAR':
          whiteboardStrokes.clear();
          break;
        case 'POLL':
          activePolls.add(Poll.fromJson(payload));
          break;
        case 'POLL_RESPONSE':
          final pollId = payload['pollId'];
          final studentId = payload['studentId'];
          final option = payload['option'];
          if (!pollResponses.containsKey(pollId)) {
            pollResponses[pollId] = {};
          }
          pollResponses[pollId]![studentId] = option;
          break;
        case 'ASSIGNMENT':
          activeAssignments.add(Assignment.fromJson(payload));
          break;
        case 'ATTENDANCE_PING':
          attendance[payload['studentId']] = DateTime.now();
          break;
        case 'RAISE_HAND':
          raisedHands.add(payload['studentId']);
          break;
        case 'LOWER_HAND':
          raisedHands.remove(payload['studentId']);
          break;
        case 'EMERGENCY_ALERT':
          lastEmergencyAlert = payload['message'];
          break;
        case 'RESOURCE_SHARED':
        case 'RESOURCE_SHARED_DIRECT':
          sharedResources.add(SharedResource.fromJson(payload));
          break;
      }
    } catch (e) {
      debugPrint('Error processing event payload: $e');
    }
  }

  // Exam Methods
  void publishQuestion(Question q) {
    final payload = json.encode(q.toJson());
    _router.broadcast('QUESTION_PUBLISHED', payload);
    activeQuestions.add(q);
    notifyListeners();
  }

  void submitAnswer(String questionId, String answer) {
    final payload = json.encode({
      'studentId': LocalStorage.deviceId,
      'questionId': questionId,
      'answer': answer,
    });
    _router.broadcast('ANSWER_SUBMITTED', payload);
    studentAnswers['${LocalStorage.deviceId}_$questionId'] = answer;
    notifyListeners();
  }

  void submitFinalExam() {
    // Collect all local answers for this student to send a final snapshot
    final myAnswers = <String, String>{};
    for (final q in activeQuestions) {
      final ans = studentAnswers['${LocalStorage.deviceId}_${q.id}'];
      if (ans != null) {
        myAnswers[q.id] = ans;
      }
    }

    final payload = json.encode({
      'studentId': LocalStorage.deviceId,
      'studentName': LocalStorage.userName,
      'rollNumber': LocalStorage.rollNumber,
      'answers': myAnswers, // Include the full snapshot
      'timestamp': DateTime.now().toIso8601String(),
    });
    _router.broadcast('EXAM_SUBMITTED', payload);
    notifyListeners();
  }

  void sendSuspicionUpdate(int bgOffenses, int faceOffenses, List<String> logs) {
    final report = SuspicionReport(
      studentId: LocalStorage.deviceId,
      backgroundOffenses: bgOffenses,
      faceOffenses: faceOffenses,
      offenseLogs: logs,
      lastUpdated: DateTime.now(),
    );
    final payload = json.encode(report.toJson());
    _router.broadcast('SUSPICION_UPDATE', payload);
    suspicionReports[LocalStorage.deviceId] = report;
    notifyListeners();
  }

  // Classroom Methods
  void sendChatMessage(String text) {
    final msg = ChatMessage(
      id: '${LocalStorage.deviceId}_${DateTime.now().millisecondsSinceEpoch}',
      senderName: LocalStorage.userName,
      text: text,
      timestamp: DateTime.now(),
    );
    final payload = json.encode(msg.toJson());
    _router.broadcast('CLASS_CHAT', payload);
    chatMessages.add(msg);
    notifyListeners();
  }

  void sendWhiteboardStroke(WhiteboardStroke stroke) {
    final payload = json.encode(stroke.toJson());
    _router.broadcast('WHITEBOARD_DATA', payload);
    whiteboardStrokes.add(stroke);
    notifyListeners();
  }

  void clearWhiteboard() {
    _router.broadcast('WHITEBOARD_CLEAR', '{}');
    whiteboardStrokes.clear();
    notifyListeners();
  }

  void sendPoll(Poll poll) {
    final payload = json.encode(poll.toJson());
    _router.broadcast('POLL', payload);
    activePolls.add(poll);
    notifyListeners();
  }

  void submitPollResponse(String pollId, String option) {
    final payload = json.encode({
      'pollId': pollId,
      'studentId': LocalStorage.deviceId,
      'option': option,
    });
    _router.broadcast('POLL_RESPONSE', payload);
    if (!pollResponses.containsKey(pollId)) pollResponses[pollId] = {};
    pollResponses[pollId]![LocalStorage.deviceId] = option;
    notifyListeners();
  }

  void sendAssignment(Assignment assignment) {
    final payload = json.encode(assignment.toJson());
    _router.broadcast('ASSIGNMENT', payload);
    activeAssignments.add(assignment);
    notifyListeners();
  }

  void sendAttendancePing() {
    final payload = json.encode({'studentId': LocalStorage.deviceId});
    _router.broadcast('ATTENDANCE_PING', payload);
    attendance[LocalStorage.deviceId] = DateTime.now();
    notifyListeners();
  }

  void raiseHand() {
    final payload = json.encode({'studentId': LocalStorage.deviceId});
    _router.broadcast('RAISE_HAND', payload);
    raisedHands.add(LocalStorage.deviceId);
    notifyListeners();
  }

  void lowerHand(String studentId) {
    final payload = json.encode({'studentId': studentId});
    _router.broadcast('LOWER_HAND', payload);
    raisedHands.remove(studentId);
    notifyListeners();
  }

  void sendEmergencyAlert(String message) {
    final payload = json.encode({'message': message});
    _router.broadcast('EMERGENCY_ALERT', payload);
    lastEmergencyAlert = message;
    notifyListeners();
  }

  void shareResource(SharedResource resource) {
    _router.shareFile(resource.path, resource);
    sharedResources.add(resource);
    notifyListeners();
  }
}
