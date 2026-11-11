import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/models/subscription_plan.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/lemony_logo.dart';
import '../../payment/qpay_sheet.dart';
import '../drama_api.dart';
import '../drama_models.dart';
import 'coin_store.dart';
import 'drama_widgets.dart';

/// What the paywall offers: the cheapest VIP plan and the coin packages. Cached for the
/// session so swiping between locked episodes doesn't refetch.
final paywallOffersProvider =
    FutureProvider<({SubscriptionPlan? plan, List<CoinPackage> packages})>((
      ref,
    ) async {
      final api = ref.read(apiClientProvider);
      SubscriptionPlan? cheapest;
      try {
        final res = await api.get<Map<String, dynamic>>(ApiEndpoints.plans);
        final plans = (res.data!['plans'] as List)
            .map(
              (p) => SubscriptionPlan.fromJson(
                Map<String, dynamic>.from(p as Map),
              ),
            )
            .toList();
        // Monthly first (lower entry price), then the cheapest.
        plans.sort((a, b) {
          if (a.isMonthly != b.isMonthly) return a.isMonthly ? -1 : 1;
          return a.priceMnt.compareTo(b.priceMnt);
        });
        cheapest = plans.isEmpty ? null : plans.first;
      } catch (_) {}
      var packages = <CoinPackage>[];
      try {
        packages = (await ref.read(dramaApiProvider).coins()).packages;
      } catch (_) {}
      return (plan: cheapest, packages: packages);
    });

/// "Unlock the next locked episodes by themselves when I have coins" — remembered on
/// this device.
class AutoUnlock extends StateNotifier<bool> {
  static const _key = 'auto_unlock';
  static const _storage = FlutterSecureStorage();
  AutoUnlock() : super(false) {
    _storage
        .read(key: _key)
        .then((v) {
          if (mounted) state = v == '1';
        })
        .catchError((_) {});
  }

  void set(bool on) {
    state = on;
    _storage.write(key: _key, value: on ? '1' : '0').catchError((_) {});
  }
}

final autoUnlockProvider = StateNotifierProvider<AutoUnlock, bool>(
  (ref) => AutoUnlock(),
);

/// Locked-episode card: coins for this episode (with top-up right here when short),
/// VIP as the better deal, and the auto-unlock switch.
class PaywallPanel extends ConsumerWidget {
  final int episodeNumber;
  final int? price;
  final int balance;
  final bool busy;
  final String? error;
  final VoidCallback onUnlock;

  /// After a coin package is paid: the player refreshes the balance and unlocks.
  final VoidCallback onCoinsBought;

  /// After VIP is paid: the player reloads the episode.
  final VoidCallback onVipBought;

  const PaywallPanel({
    super.key,
    required this.episodeNumber,
    required this.price,
    required this.balance,
    required this.busy,
    required this.onUnlock,
    required this.onCoinsBought,
    required this.onVipBought,
    this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(paywallOffersProvider).valueOrNull;
    final auto = ref.watch(autoUnlockProvider);
    final enough = price != null && balance >= price!;
    final plan = offers?.plan;
    final packages = (offers?.packages ?? const <CoinPackage>[])
        .take(3)
        .toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xF0141318),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                '$episodeNumber-р анги түгжээтэй',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Таны зоос: ',
                    style: TextStyle(color: DramaColors.muted, fontSize: 13),
                  ),
                  const CoinIcon(size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$balance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── This episode with coins ──
              if (price != null) ...[
                SizedBox(
                  height: 50,
                  child: GradientPill(
                    label: busy
                        ? 'Нээж байна…'
                        : enough
                        ? '$price зоосоор нээх'
                        : '$price зоос хэрэгтэй · ${price! - balance} дутуу',
                    icon: busy ? null : Icons.lock_open_rounded,
                    onTap: busy || !enough ? null : onUnlock,
                  ),
                ),
                if (!enough && packages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Зоос нэмэх',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < packages.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _PackChip(
                            pack: packages[i],
                            onTap: () => QPaySheet.show(
                              context: context,
                              amount: packages[i].price,
                              description:
                                  '${packages[i].coins + packages[i].bonus} зоос',
                              invoiceType: 'coins',
                              coinPackageId: packages[i].id,
                              onSuccess: onCoinsBought,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),
              ],

              // ── VIP: the better deal ──
              if (plan != null)
                _VipOffer(
                  plan: plan,
                  onTap: () => QPaySheet.show(
                    context: context,
                    amount: plan.priceMnt,
                    description: '${plan.name} VIP',
                    invoiceType: 'subscription',
                    planId: plan.id,
                    onSuccess: onVipBought,
                  ),
                ),

              // ── Auto-unlock ──
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Дараагийн ангиудыг автоматаар нээх',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  Switch(
                    value: auto,
                    activeThumbColor: Colors.white,
                    activeTrackColor: LemonyBrand.rose,
                    onChanged: (v) =>
                        ref.read(autoUnlockProvider.notifier).set(v),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PackChip extends StatelessWidget {
  final CoinPackage pack;
  final VoidCallback onTap;
  const _PackChip({required this.pack, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: DramaColors.surface2,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CoinIcon(size: 15),
                const SizedBox(width: 4),
                Text(
                  '${pack.coins + pack.bonus}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            // Always a bonus line (blank when none) so the three tiles line up.
            Text(
              pack.bonus > 0 ? '+${pack.bonus} бонус' : ' ',
              style: const TextStyle(
                color: LemonyBrand.amber,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMnt(pack.price),
              style: const TextStyle(color: DramaColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VipOffer extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onTap;
  const _VipOffer({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF3B2A12), Color(0xFF2A1A24)],
            ),
            border: Border.all(color: const Color(0xAAF5B83D)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.diamond_rounded,
                    color: DramaColors.gold,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIP · ${formatMnt(plan.priceMnt)} / ${plan.isYearly ? 'жил' : 'сар'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Бүх драмын бүх анги хязгааргүй',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: DramaColors.gold,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: -9,
        right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            gradient: LemonyBrand.gradient,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Хамгийн ашигтай',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );
}
