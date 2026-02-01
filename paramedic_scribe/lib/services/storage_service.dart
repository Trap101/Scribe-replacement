import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/report_model.dart';

class StorageService {
  static const String _boxName = 'reports';
  static const String _sessionKey = '__current_session__';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_boxName);
  }

  Future<void> saveReport(ParamedicReport report) async {
    final box = Hive.box<String>(_boxName);
    await box.put(report.reportId, jsonEncode(report.toJson()));
  }

  Future<void> saveSession(ParamedicReport report) async {
    final box = Hive.box<String>(_boxName);
    await box.put(_sessionKey, jsonEncode(report.toJson()));
  }

  ParamedicReport? loadSession() {
    final box = Hive.box<String>(_boxName);
    final json = box.get(_sessionKey);
    if (json == null) return null;
    try {
      return ParamedicReport.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final box = Hive.box<String>(_boxName);
    await box.delete(_sessionKey);
  }

  List<String> getAllReportIds() {
    final box = Hive.box<String>(_boxName);
    return box.keys.cast<String>().where((k) => k != _sessionKey).toList();
  }

  String? getReportJson(String reportId) {
    final box = Hive.box<String>(_boxName);
    return box.get(reportId);
  }

  Future<void> deleteReport(String reportId) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(reportId);
  }
}
