import 'prediction_result.dart';

class Patient {
  final String? id; // Add id field for Firebase
  final String name;
  final String phoneNumber;
  final int age;
  final String gender;
  final DateTime date;
  final PredictionResult? emotionResults;
  final String? bloodGroup;
  final String? additionalNotes;
  final String? email;

  Patient({
    this.id, // Make it optional
    required this.name,
    required this.phoneNumber,
    required this.age,
    required this.gender,
    required this.date,
    this.emotionResults,
    this.bloodGroup,
    this.additionalNotes,
    this.email,
  });

  Patient copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    int? age,
    String? gender,
    DateTime? date,
    PredictionResult? emotionResults,
    String? bloodGroup,
    String? additionalNotes,
    String? email,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      date: date ?? this.date,
      emotionResults: emotionResults ?? this.emotionResults,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'age': age,
      'gender': gender,
      'date': date.millisecondsSinceEpoch,
      'emotionResults': emotionResults?.toMap(),
      'bloodGroup': bloodGroup,
      'additionalNotes': additionalNotes,
      'email': email,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as String?,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      age: map['age'] as int,
      gender: map['gender'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      emotionResults: map['emotionResults'] != null
          ? PredictionResult.fromMap(Map<String, dynamic>.from(map['emotionResults'] as Map))
          : null,
      bloodGroup: map['bloodGroup'] as String?,
      additionalNotes: map['additionalNotes'] as String?,
      email: map['email'] as String?,
    );
  }

  @override
  String toString() {
    return 'Patient{id: $id, name: $name, age: $age, gender: $gender}';
  }
}