// lib/models/user.dart
class User {
  final int id;
  final String email;
  final String username;
  final String? firstName;
  final String? lastName;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.firstName,
    this.lastName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      username: json['username'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
    };
  }
}