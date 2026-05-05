import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/subscription_plan.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../payment/qpay_sheet.dart';

final _plansProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get<Map<String, dynamic>>(ApiEndpoints.plans);
  return (res.data!['plans'] as List<dynamic>)
      .map((p) => SubscriptionPlan.fromJson(p as Map<String, dynamic>))
      .toList();
});

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(_plansProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Багцууд',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: plansAsync.when(
        loading: () => const _PlansShimmer(),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppTheme.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Багцуудыг ачаалж чадсангүй',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(_plansProvider),
                child: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
        data: (plans) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active subscription banner
              if (user?.hasActiveSubscription == true) ...[
                _StatusBanner(
                  icon: Icons.workspace_premium_rounded,
                  text:
                      '${_formatDate(user!.subscriptionEndsAt)} хүртэл идэвхтэй',
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: 24),
              ],

              // Headline
              const Text(
                'Хязгааргүй үзвэр.\nХэзээ ч цуцлах боломжтой.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Кино, цувралаа хаанаас ч, хэзээ ч үзээрэй.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Feature highlights
              const _FeatureRow(
                icon: Icons.hd_rounded,
                label: 'HD чанартай үзвэр',
              ),
              const SizedBox(height: 10),
              const _FeatureRow(
                icon: Icons.devices_rounded,
                label: 'Дурын төхөөрөмжөөс үзэх',
              ),
              const SizedBox(height: 10),
              const _FeatureRow(
                icon: Icons.video_library_rounded,
                label: 'Кино, цувралд бүрэн хандах',
              ),
              const SizedBox(height: 32),

              // Plan cards
              ...plans.map(
                (plan) => _PlanCard(
                  plan: plan,
                  onSubscribe: () async {
                    await QPaySheet.show(
                      context: context,
                      amount: plan.priceMnt,
                      description: '${plan.name} багц',
                      invoiceType: 'subscription',
                      planId: plan.id,
                      onSuccess: () {
                        ref.invalidate(_plansProvider);
                        ref.read(authProvider.notifier).refreshUser();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Багц амжилттай идэвхжлээ!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Төлбөр QPay-ээр аюулгүй хийгдэнэ.\nБүртгэлээсээ хэзээ ч цуцлах боломжтой.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ─── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onSubscribe;

  const _PlanCard({required this.plan, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    final isYearly = plan.isYearly;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isYearly
            ? Border.all(color: AppTheme.primary, width: 2)
            : Border.all(color: Colors.white12),
        boxShadow: isYearly
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (isYearly)
            Positioned(
              top: 0,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  'ХАМГИЙН АШИГТАЙ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.isMonthly ? 'сараар' : 'жилээр',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan.priceFormatted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (plan.isYearly)
                          Text(
                            '(${_monthlyRate(plan.priceMnt)}/сар)',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (plan.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    plan.description!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isYearly
                          ? AppTheme.primary
                          : Colors.white,
                      foregroundColor: isYearly ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: isYearly ? 4 : 0,
                    ),
                    child: const Text(
                      'Эхлэх',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthlyRate(double yearly) {
    final monthly = yearly / 12;
    return '₮${monthly.toStringAsFixed(0)}';
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 17),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}

class _PlansShimmer extends StatelessWidget {
  const _PlansShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const ShimmerBox(width: double.infinity, height: 24),
          const SizedBox(height: 8),
          const ShimmerBox(width: 200, height: 16),
          const SizedBox(height: 32),
          ...List.generate(
            2,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: ShimmerBox(width: double.infinity, height: 160),
            ),
          ),
        ],
      ),
    );
  }
}
