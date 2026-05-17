import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/loading_shimmer.dart';

final _rentalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get<Map<String, dynamic>>(ApiEndpoints.rentals);
  return (res.data!['rentals'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
});

class RentalsScreen extends ConsumerWidget {
  const RentalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentalsAsync = ref.watch(_rentalsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Миний түрээс', style: TextStyle(color: Colors.white, fontSize: 17)),
      ),
      body: rentalsAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => const ShimmerBox(height: 90),
        ),
        error: (_, __) => const Center(
          child: Text('Түрээсийн мэдээлэл авахад алдаа гарлаа',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (rentals) => rentals.isEmpty
            ? _Empty()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rentals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _RentalTile(rental: rentals[i]),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined, color: AppTheme.textSecondary, size: 52),
          const SizedBox(height: 16),
          const Text('Түрээсэлсэн үзвэр байхгүй байна',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Түрээс идэвхжсэнээс хойш 72 цаг хүчинтэй.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _RentalTile extends StatelessWidget {
  final Map<String, dynamic> rental;
  const _RentalTile({required this.rental});

  @override
  Widget build(BuildContext context) {
    final title = rental['title'] as String? ?? '';
    final posterUrl = rental['poster_url'] as String?;
    final expiresAt = rental['expires_at'] as String?;
    final slug = rental['slug'] as String?;
    final type = rental['content_type'] as String? ?? 'movie';

    DateTime? expiry;
    if (expiresAt != null) expiry = DateTime.tryParse(expiresAt);
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());

    return GestureDetector(
      onTap: slug == null || isExpired
          ? null
          : () => type == 'movie'
              ? context.push('/movies/$slug')
              : context.push('/shows/$slug'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Poster
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              child: SizedBox(
                width: 64,
                height: 90,
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ShimmerBox(),
                        errorWidget: (_, __, ___) => _posterPlaceholder(),
                      )
                    : _posterPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    if (expiry != null)
                      Text(
                        isExpired
                            ? 'Хугацаа дууссан'
                            : 'Дуусах: ${_format(expiry)}',
                        style: TextStyle(
                          color: isExpired ? AppTheme.primary : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!isExpired)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.play_circle_outline_rounded, color: AppTheme.textSecondary, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _posterPlaceholder() => Container(
        color: AppTheme.surface,
        child: const Icon(Icons.movie_outlined, color: AppTheme.textSecondary),
      );

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
