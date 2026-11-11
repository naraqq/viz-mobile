import 'json_helpers.dart';

class User {
  final int id;
  final String name;

  /// Null for phone and guest accounts.
  final String? email;
  final String? phone;
  final bool phoneVerified;
  final bool hasPin;

  /// 6-digit guest number; set only for guest accounts.
  final String? guestCode;
  final String role;
  final bool hasPassword;
  final DateTime? subscriptionEndsAt;
  final bool hasActiveSubscription;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.phoneVerified = false,
    this.hasPin = false,
    this.guestCode,
    required this.role,
    this.hasPassword = true,
    this.subscriptionEndsAt,
    this.hasActiveSubscription = false,
  });

  bool get isAdmin => role == 'admin';
  bool get isGuest => guestCode != null;

  /// What to show under the name: email, phone, or the guest number.
  String get contactLabel =>
      email ??
      (phone != null
          ? phone!
          : (guestCode != null ? 'Зочны дугаар: $guestCode' : ''));

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: readInt(json['id']) ?? 0,
    name: json['name'] as String,
    email: json['email'] as String?,
    phone: json['phone']?.toString(),
    phoneVerified: readBool(json['phone_verified']),
    hasPin: readBool(json['has_pin']),
    guestCode: json['guest_code']?.toString(),
    role: json['role'] as String? ?? 'user',
    hasPassword: readBool(json['has_password'], fallback: true),
    subscriptionEndsAt: json['subscription_ends_at'] != null
        ? DateTime.tryParse(json['subscription_ends_at'] as String)
        : null,
    hasActiveSubscription: readBool(json['has_active_subscription']),
  );
}
