import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prediction_history.dart';

class PredictionHistoryService {
  static const String _historyKey = 'prediction_history';
  static final PredictionHistoryService _instance = PredictionHistoryService._internal();

  factory PredictionHistoryService() => _instance;
  PredictionHistoryService._internal();

  List<PredictionRecord> _history = [];

  Future<void> initialize() async {
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];

      _history = historyJson.map((json) {
        try {
          return PredictionRecord.fromMap(jsonDecode(json));
        } catch (e) {
          debugPrint('Error parsing prediction record: $e');
          return null;
        }
      }).whereType<PredictionRecord>().toList();

      // Sort by date (newest first)
      _history.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } catch (e) {
      debugPrint('Error loading history: $e');
      _history = [];
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _history.map((record) => jsonEncode(record.toMap())).toList();
      await prefs.setStringList(_historyKey, historyJson);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  Future<void> addPrediction({
    required String emotion,
    required double confidence,
    String? csvFileName,
    String? method,
  }) async {
    final record = PredictionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      emotion: emotion,
      confidence: confidence,
      csvFileName: csvFileName,
      method: method,
    );

    _history.insert(0, record);
    await _saveHistory();
  }

  List<PredictionRecord> getHistory() {
    return List.from(_history);
  }

  List<PredictionRecord> getHistoryForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _history.where((record) {
      final recordDate = DateTime(record.dateTime.year, record.dateTime.month, record.dateTime.day);
      return recordDate == targetDate;
    }).toList();
  }

  Map<DateTime, List<PredictionRecord>> getGroupedHistory() {
    final grouped = <DateTime, List<PredictionRecord>>{};

    for (final record in _history) {
      final date = DateTime(record.dateTime.year, record.dateTime.month, record.dateTime.day);
      grouped.update(
        date,
            (existing) => [...existing, record],
        ifAbsent: () => [record],
      );
    }

    return grouped;
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
  }

  int get totalPredictions => _history.length;

  List<DateTime> getDatesWithHistory() {
    return getGroupedHistory().keys.toList();
  }

  // Get statistics
  Map<String, int> getEmotionDistribution() {
    final distribution = <String, int>{};
    for (final record in _history) {
      distribution.update(
        record.emotion,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return distribution;
  }

  double getAverageConfidence() {
    if (_history.isEmpty) return 0.0;
    final total = _history.fold(0.0, (sum, record) => sum + record.confidence);
    return total / _history.length;
  }
}