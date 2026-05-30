import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mesh/mesh_router.dart';
import '../models/models.dart';
import '../storage/local_storage.dart';

import 'package:flutter/foundation.dart';

final syncProvider = ChangeNotifierProvider((ref) => SyncEngine(ref.read(meshProvider)));

class SyncEngine extends ChangeNotifier {
  final MeshRouter _router;

  List<Question> activeQuestions = [];
  Map<String, String> studentAnswers = {};

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
      }
    } catch (e) {
      debugPrint('Error processing event payload: $e');
    }
  }

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
}
