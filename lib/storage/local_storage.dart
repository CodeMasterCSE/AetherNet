import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class LocalStorage {
  static late Box _settingsBox;
  static late Box _messagesBox;
  static late Box _templatesBox;
  static late Box _classroomsBox;

  static Future<void> init() async {
    _settingsBox = await Hive.openBox('settings');
    _messagesBox = await Hive.openBox('messages');
    _templatesBox = await Hive.openBox('templates');
    _classroomsBox = await Hive.openBox('classrooms');

    // Generate a unique device ID if not exists
    if (_settingsBox.get('deviceId') == null) {
      await _settingsBox.put('deviceId', const Uuid().v4());
    }
  }

  static String get deviceId => _settingsBox.get('deviceId');

  static String get userName =>
      _settingsBox.get('userName', defaultValue: 'Unknown Device');
  static Future<void> setUserName(String name) async =>
      await _settingsBox.put('userName', name);

  static bool get isTeacher =>
      _settingsBox.get('isTeacher', defaultValue: false);
  static Future<void> setIsTeacher(bool val) async =>
      await _settingsBox.put('isTeacher', val);

  static String get paperName =>
      _settingsBox.get('paperName', defaultValue: '');
  static Future<void> setPaperName(String val) async =>
      await _settingsBox.put('paperName', val);

  static String get examCode => _settingsBox.get('examCode', defaultValue: '');
  static Future<void> setExamCode(String val) async =>
      await _settingsBox.put('examCode', val);

  static String get rollNumber =>
      _settingsBox.get('rollNumber', defaultValue: '');
  static Future<void> setRollNumber(String val) async =>
      await _settingsBox.put('rollNumber', val);

  static Future<void> saveMessage(
      String id, Map<String, dynamic> messageMap) async {
    await _messagesBox.put(id, messageMap);
  }

  static bool hasMessage(String id) {
    return _messagesBox.containsKey(id);
  }

  static List<Map<String, dynamic>> getAllMessages() {
    return _messagesBox.values.map((e) {
      final raw = e as Map;
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }).toList();
  }

  static Future<void> clearSessionData() async {
    // Clear all mesh messages (questions and responses)
    await _messagesBox.clear();
  }

  // ── Paper Templates & Question Bank ──

  static Future<void> saveTemplate(PaperTemplate template) async {
    await _templatesBox.put(template.id, json.encode(template.toJson()));
  }

  static List<PaperTemplate> getAllTemplates() {
    return _templatesBox.values.map((e) {
      return PaperTemplate.fromJson(json.decode(e as String));
    }).toList();
  }

  static Future<void> deleteTemplate(String id) async {
    await _templatesBox.delete(id);
  }

  // ── Classrooms ──

  static Future<void> saveClassroom(Classroom classroom) async {
    await _classroomsBox.put(classroom.id, json.encode(classroom.toJson()));
  }

  static List<Classroom> getAllClassrooms() {
    return _classroomsBox.values.map((e) {
      return Classroom.fromJson(json.decode(e as String));
    }).toList();
  }

  static Classroom? getClassroom(String id) {
    final data = _classroomsBox.get(id);
    if (data != null) {
      return Classroom.fromJson(json.decode(data as String));
    }
    return null;
  }

  static Future<void> deleteClassroom(String id) async {
    await _classroomsBox.delete(id);
  }
}
