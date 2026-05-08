class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? link;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.link,
    required this.isRead,
    required this.createdAt,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        body: body,
        imageUrl: imageUrl,
        link: link,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        imageUrl: json['image_url'] as String?,
        link: json['link'] as String?,
        isRead: json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
