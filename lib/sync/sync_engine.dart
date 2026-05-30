import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mesh/mesh_router.dart';
import '../models/models.dart';
import '../storage/local_storage.dart';

import 'package:flutter/foundation.dart';

final syncProvider = ChangeNotifierProvider((ref) => SyncEngine(ref.read(meshProvider)));

class SyncEngine extends ChangeNotifier {
  final MeshRouter _router;

  // Exam Mode State
  List<Question> activeQuestions = [];
  Map<String, String> studentAnswers = {};

  // Classroom Mode State
  List<ChatMessage> chatMessages = [];
  List<WhiteboardStroke> whiteboardStrokes = [];
  List<Poll> activePolls = [];
  Map<String, Map<String, String>> pollResponses = {}; // pollId -> {studentId: option}
  List<Assignment> activeAssignments = [];
  Map<String, DateTime> attendance = {}; // studentId -> last seen
  Set<String> raisedHands = {}; // studentIds
  String? lastEmergencyAlert;

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
    chatMessages.clear();
    whiteboardStrokes.clear();
    activePolls.clear();
    pollResponses.clear();
    activeAssignments.clear();
    attendance.clear();
    raisedHands.clear();
    lastEmergencyAlert = null;
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
          // Bulk update answers from final submission snapshot
          if (payload['answers'] != null) {
            final Map<String, dynamic> bulkAnswers = payload['answers'];
            bulkAnswers.forEach((qId, ans) {
              studentAnswers['${payload['studentId']}_$qId'] = ans.toString();
            });
          }
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
}
