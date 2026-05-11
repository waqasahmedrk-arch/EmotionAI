import 'package:flutter/foundation.dart';

@immutable
class PredictionRecord {
  final String id;
  final DateTime dateTime;
  final String emotion;
  final double confidence;
  final String? csvFileName;
  final String? method; // 'csv' or 'realtime'

  const PredictionRecord({
    required this.id,
    required this.dateTime,
    required this.emotion,
    required this.confidence,
    this.csvFileName,
    this.method,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'emotion': emotion,
      'confidence': confidence,
      'csvFileName': csvFileName,
      'method': method,
    };
  }

  factory PredictionRecord.fromMap(Map<String, dynamic> map) {
    return PredictionRecord(
      id: map['id'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      emotion: map['emotion'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      csvFileName: map['csvFileName'] as String?,
      method: map['method'] as String?,
    );
  }

  @override
  String toString() {
    return 'PredictionRecord{id: $id, emotion: $emotion, confidence: $confidence, dateTime: $dateTime}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PredictionRecord &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}