class AppConfig {
  final bool reviewMode;
  final String minVersion;
  final String? storeUrl;

  const AppConfig({
    required this.reviewMode,
    required this.minVersion,
    this.storeUrl,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        reviewMode: json['review_mode'] as bool? ?? false,
        minVersion: json['min_version'] as String? ?? '1.0.0',
        storeUrl: json['store_url'] as String?,
      );

  static const empty = AppConfig(reviewMode: false, minVersion: '1.0.0');
}
