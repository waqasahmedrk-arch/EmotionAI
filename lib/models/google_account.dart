// models/google_account.dart
class GoogleAccount {
  final String name;
  final String email;
  final String avatar;
  final bool isVerified;
  final DateTime? addedDate;

  GoogleAccount({
    required this.name,
    required this.email,
    required this.avatar,
    required this.isVerified,
    this.addedDate,
  });

  // Helper method to get initials for avatar
  static String getInitials(String name) {
    List<String> names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0].substring(0, names[0].length < 2 ? names[0].length : 2).toUpperCase();
    }
    return 'U';
  }

  // Create a verified copy of the account
  GoogleAccount copyWithVerified() {
    return GoogleAccount(
      name: name,
      email: email,
      avatar: avatar,
      isVerified: true,
      addedDate: DateTime.now(),
    );
  }
}