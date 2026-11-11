import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/models/subscription_plan.dart';
import '../../core/providers/auth_provider.dart';
import '../payment/qpay_sheet.dart';
import 'drama_api.dart';
import 'drama_models.dart';
import 'widgets/coin_store.dart';
import 'widgets/drama_widgets.dart';
import '../rewards/rewards_api.dart';
import '../rewards/rewards_section.dart';

final _vipDataProvider =
    FutureProvider.autoDispose<
      ({List<SubscriptionPlan> plans, int balance, List<CoinPackage> packages})
    >((ref) async {
      final api = ref.read(apiClientProvider);
      final coins = ref.read(dramaApiProvider).coins();
      // Plans failing must not hide the coin packages (and vice versa below).
      var plans = <SubscriptionPlan>[];
      try {
        final res = await api.get<Map<String, dynamic>>(ApiEndpoints.plans);
        plans = (res.data!['plans'] as List)
            .map(
              (p) => SubscriptionPlan.fromJson(
                Map<String, dynamic>.from(p as Map),
              ),
            )
            .toList();
      } catch (_) {}
      final c = await coins;
      ref.read(coinBalanceProvider.notifier).state = c.balance;
      return (plans: plans, balance: c.balance, packages: c.packages);
    });

/// Шагнал tab: coin balance, daily check-in and watch tasks, then VIP plans and coin
/// packages.
class VipScreen extends ConsumerWidget {
  const VipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final async = ref.watch(_vipDataProvider);
    final balance = ref.watch(coinBalanceProvider);
    final pad = MediaQuery.of(context).padding;
    final isVip = user?.hasActiveSubscription ?? false;

    return Scaffold(
      backgroundColor: DramaColors.bg,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: DramaColors.surface,
        onRefresh: () {
          ref.invalidate(rewardsProvider);
          return ref.refresh(_vipDataProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: DramaColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CoinIcon(size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Миний зоос',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const Spacer(),
                  Text(
                    '${balance ?? async.valueOrNull?.balance ?? '—'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const RewardsSection(),
            const _Title('VIP'),
            // Status card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A2A10), Color(0xFF241A2B)],
                ),
                border: Border.all(color: const Color(0x44F5B83D)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: DramaColors.gold,
                    size: 40,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVip ? 'Та VIP гишүүн' : 'VIP болох',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isVip && user?.subscriptionEndsAt != null
                              ? '${_date(user!.subscriptionEndsAt!)} хүртэл бүх анги нээлттэй'
                              : 'Бүх драмын бүх ангийг хязгааргүй үзээрэй',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...async.when(
              loading: () => [
                const SizedBox(height: 24),
                const SkeletonBox(height: 84),
                const SizedBox(height: 10),
                const SkeletonBox(height: 84),
              ],
              error: (e, _) => [
                const SizedBox(height: 40),
                ErrorRetry(
                  message: '$e',
                  onRetry: () => ref.invalidate(_vipDataProvider),
                ),
              ],
              data: (data) => [
                if (data.plans.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final p in data.plans)
                    _PlanTile(
                      plan: p,
                      onTap: () => QPaySheet.show(
                        context: context,
                        amount: p.priceMnt,
                        description: '${p.name} VIP',
                        invoiceType: 'subscription',
                        planId: p.id,
                        onSuccess: () {
                          ref.read(authProvider.notifier).refreshUser();
                          ref.invalidate(_vipDataProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('VIP амжилттай идэвхжлээ!'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        },
                      ),
                    ),
                ],
                const _Title('Зоос цэнэглэх'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Зоосоор түгжээтэй ангийг нэг нэгээр нээнэ.',
                    style: TextStyle(color: DramaColors.muted, fontSize: 13),
                  ),
                ),
                CoinPackagesGrid(packages: data.packages),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 26, 0, 12),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PlanTile extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onTap;
  const _PlanTile({required this.plan, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: DramaColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((plan.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        plan.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DramaColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMnt(plan.priceMnt),
                    style: const TextStyle(
                      color: DramaColors.gold,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    plan.isYearly ? '/ жил' : '/ сар',
                    style: const TextStyle(
                      color: DramaColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
