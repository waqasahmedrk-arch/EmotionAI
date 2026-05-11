// models/user_model.dart
class User {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final bool isGuest;
  final bool isVerified; // NEW: OTP verification status
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    this.isGuest = false,
    this.isVerified = false, // Default to false for new users
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      isGuest: json['isGuest'] ?? false,
      isVerified: json['isVerified'] ?? false, // NEW
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'isGuest': isGuest,
      'isVerified': isVerified, // NEW
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImage,
    bool? isGuest,
    bool? isVerified, // NEW
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      isGuest: isGuest ?? this.isGuest,
      isVerified: isVerified ?? this.isVerified, // NEW
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}