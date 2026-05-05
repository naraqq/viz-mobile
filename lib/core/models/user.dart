import 'json_helpers.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final DateTime? subscriptionEndsAt;
  final bool hasActiveSubscription;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.subscriptionEndsAt,
    this.hasActiveSubscription = false,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: readInt(json['id']) ?? 0,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String? ?? 'user',
        subscriptionEndsAt: json['subscription_ends_at'] != null
            ? DateTime.tryParse(json['subscription_ends_at'] as String)
            : null,
        hasActiveSubscription: readBool(json['has_active_subscription']),
      );
}
