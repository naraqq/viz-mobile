import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/lemony_logo.dart';
import '../../payment/qpay_sheet.dart';
import '../drama_api.dart';
import '../drama_models.dart';
import 'drama_widgets.dart';

String formatMnt(double v) {
  final s = v.toStringAsFixed(0);
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b₮';
}

class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 18});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [Color(0xFFFFD66B), Color(0xFFF59E0B)]),
    ),
    alignment: Alignment.center,
    child: Text(
      '₮',
      style: TextStyle(
        color: const Color(0xFF7C4A03),
        fontSize: size * 0.6,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}

/// Grid of coin packages; buying one opens QPay. Used in the VIP tab and as a sheet.
class CoinPackagesGrid extends ConsumerWidget {
  final List<CoinPackage> packages;
  final VoidCallback? onPurchased;
  const CoinPackagesGrid({super.key, required this.packages, this.onPurchased});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (packages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Одоогоор зоосны багц алга.',
          style: TextStyle(color: DramaColors.muted),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.86,
      children: [
        for (final p in packages)
          _PackageTile(
            p: p,
            onTap: () => QPaySheet.show(
              context: context,
              amount: p.price,
              description: '${p.coins + p.bonus} зоос',
              invoiceType: 'coins',
              coinPackageId: p.id,
              onSuccess: () async {
                final c = await ref.read(dramaApiProvider).coins();
                ref.read(coinBalanceProvider.notifier).state = c.balance;
                onPurchased?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${p.coins + p.bonus} зоос нэмэгдлээ!'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}

class _PackageTile extends StatelessWidget {
  final CoinPackage p;
  final VoidCallback onTap;
  const _PackageTile({required this.p, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: DramaColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinIcon(size: 18),
                    const SizedBox(width: 5),
                    Text(
                      '${p.coins}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  p.bonus > 0 ? '+${p.bonus} бонус' : ' ',
                  style: const TextStyle(
                    color: DramaColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: DramaColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatMnt(p.price),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (p.badge != null && p.badge!.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  gradient: LemonyBrand.gradient,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Text(
                  p.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Bottom sheet: balance + packages (+ a link to VIP).
Future<void> showCoinStoreSheet(
  BuildContext context, {
  VoidCallback? onPurchased,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: DramaColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CoinStoreSheet(onPurchased: onPurchased),
  );
}

class _CoinStoreSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPurchased;
  const _CoinStoreSheet({this.onPurchased});
  @override
  ConsumerState<_CoinStoreSheet> createState() => _CoinStoreSheetState();
}

class _CoinStoreSheetState extends ConsumerState<_CoinStoreSheet> {
  late final Future<({int balance, List<CoinPackage> packages})> _load = ref
      .read(dramaApiProvider)
      .coins();

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(coinBalanceProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: FutureBuilder(
          future: _load,
          builder: (context, snap) {
            final data = snap.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DramaColors.faint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Зоос цэнэглэх',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const CoinIcon(size: 16),
                    const SizedBox(width: 5),
                    Text(
                      '${balance ?? data?.balance ?? 0}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (snap.connectionState != ConnectionState.done)
                  const SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  )
                else if (snap.hasError)
                  Text(
                    '${snap.error}',
                    style: const TextStyle(color: DramaColors.muted),
                  )
                else
                  CoinPackagesGrid(
                    packages: data!.packages,
                    onPurchased: () {
                      widget.onPurchased?.call();
                      Navigator.of(context).maybePop();
                    },
                  ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/vip');
                  },
                  child: const Text(
                    'VIP болж бүх ангийг хязгааргүй үзэх →',
                    style: TextStyle(color: DramaColors.gold),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shown on a locked episode page: price, balance, unlock with coins, or go VIP.
class UnlockPanel extends StatelessWidget {
  final int episodeNumber;
  final int? price;
  final int balance;
  final bool busy;
  final String? error;
  final VoidCallback onUnlock;
  final VoidCallback onBuyCoins;
  final VoidCallback onVip;
  const UnlockPanel({
    super.key,
    required this.episodeNumber,
    required this.price,
    required this.balance,
    required this.busy,
    required this.onUnlock,
    required this.onBuyCoins,
    required this.onVip,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final enough = price != null && balance >= price!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xE6141318),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 10),
          Text(
            '$episodeNumber-р анги түгжээтэй',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Үлдэгдэл: ',
                style: TextStyle(color: DramaColors.muted, fontSize: 13),
              ),
              const CoinIcon(size: 14),
              const SizedBox(width: 4),
              Text(
                '$balance',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (price != null)
            SizedBox(
              width: double.infinity,
              child: GradientPill(
                label: busy
                    ? 'Нээж байна…'
                    : enough
                    ? '$price зоосоор нээх'
                    : 'Зоос цэнэглэх',
                icon: busy ? null : Icons.lock_open_rounded,
                onTap: busy ? null : (enough ? onUnlock : onBuyCoins),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onVip,
              icon: const Icon(Icons.workspace_premium_rounded, size: 20),
              label: const Text(
                'VIP болох — бүх анги нээлттэй',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: DramaColors.gold,
                side: const BorderSide(color: Color(0x66F5B83D)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
