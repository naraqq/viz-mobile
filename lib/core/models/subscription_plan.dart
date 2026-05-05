import 'json_helpers.dart';

class SubscriptionPlan {
  final int id;
  final String name;
  final String slug;
  final double priceMnt;
  final String interval; // 'monthly' or 'yearly'
  final String? description;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.slug,
    required this.priceMnt,
    required this.interval,
    this.description,
  });

  bool get isMonthly => interval == 'monthly';
  bool get isYearly => interval == 'yearly';

  String get priceFormatted {
    final price = priceMnt.toStringAsFixed(0);
    return '₮$price';
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: readInt(json['id']) ?? 0,
        name: json['name'] as String,
        slug: json['slug'] as String,
        priceMnt: readDouble(json['price_mnt']) ?? 0,
        interval: json['interval'] as String,
        description: json['description'] as String?,
      );
}
