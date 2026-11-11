import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/widgets/lemony_logo.dart';
import '../drama/drama_api.dart';
import '../drama/widgets/coin_store.dart';
import '../drama/widgets/drama_widgets.dart';

final _balanceLoader = FutureProvider.autoDispose<void>((ref) async {
  final c = await ref.read(dramaApiProvider).coins();
  ref.read(coinBalanceProvider.notifier).state = c.balance;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: DramaColors.bg,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final reviewMode = ref.watch(reviewModeProvider);
    final library = ref.watch(myListProvider);
    ref.watch(_balanceLoader);
    final pad = MediaQuery.of(context).padding;

    Future<void> refresh() async {
      ref.invalidate(_balanceLoader);
      await Future.wait([
        ref.refresh(myListProvider.future),
        ref.read(authProvider.notifier).refreshUser(),
      ]);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DramaColors.bg,
        body: RefreshIndicator(
          color: Colors.white,
          backgroundColor: DramaColors.surface,
          onRefresh: refresh,
          child: ListView(
            padding: EdgeInsets.only(top: pad.top + 8, bottom: 24),
            children: [
              _Header(user: user),
              if (!user.phoneVerified)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _VerifyNudge(hasPhone: user.phone != null),
                ),
              if (!reviewMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _WalletCard(user: user),
                ),
              ...library.when(
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
                    child: SkeletonBox(width: 120, height: 18),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: List.generate(
                        4,
                        (_) => const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: SkeletonBox(width: 108, height: 150),
                        ),
                      ),
                    ),
                  ),
                ],
                // The rest of the profile works without it; just leave the rows out.
                error: (_, __) => const [],
                data: (lib) => [
                  if (lib.history.isNotEmpty) ...[
                    const SectionHeader('Үзсэн түүх'),
                    SizedBox(
                      height: DramaPoster.cardHeight(
                        context,
                        ContinuePoster.width,
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: lib.history.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) =>
                            ContinuePoster(item: lib.history[i]),
                      ),
                    ),
                  ],
                  const SectionHeader('Миний жагсаалт'),
                  if (lib.saved.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptySaved(),
                    )
                  else
                    SizedBox(
                      height: DramaPoster.cardHeight(context, 108),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: lib.saved.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) =>
                            DramaPoster(drama: lib.saved[i], width: 108),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Group(
                  children: [
                    _Tile(
                      icon: Icons.edit_outlined,
                      label: 'Профайл засах',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    _Tile(
                      icon: user.phoneVerified
                          ? Icons.verified_rounded
                          : Icons.phone_iphone_rounded,
                      label: 'Утасны дугаар',
                      trailing: user.phoneVerified
                          ? 'Баталгаажсан'
                          : 'Баталгаажуулах',
                      trailingColor: user.phoneVerified
                          ? const Color(0xFF4ADE80)
                          : DramaColors.gold,
                      onTap: user.phoneVerified
                          ? null
                          : () => context.push('/profile/verify-phone'),
                    ),
                    _Tile(
                      icon: Icons.info_outline_rounded,
                      label: 'Аппын тухай',
                      onTap: () => context.push('/profile/about'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Group(
                  children: [
                    _Tile(
                      icon: Icons.logout_rounded,
                      label: 'Гарах',
                      color: LemonyBrand.rose,
                      showChevron: false,
                      onTap: () => _confirmLogout(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DramaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Гарах уу?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Дахин нэвтрэхэд утасны дугаар, ПИН код хэрэгтэй.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DramaColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: LemonyBrand.rose,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(authProvider.notifier).logout();
                  },
                  child: const Text(
                    'Гарах',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Болих', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final User user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim()[0].toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          // Gradient ring avatar
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LemonyBrand.gradient,
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: DramaColors.surface2,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (user.hasActiveSubscription) ...[
                      const SizedBox(width: 8),
                      const _VipBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.contactLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DramaColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (user.phone != null && user.phoneVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF4ADE80),
                        size: 15,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Профайл засах',
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF5B83D), Color(0xFFE08A1E)],
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.diamond_rounded, color: Colors.black, size: 12),
        SizedBox(width: 3),
        Text(
          'VIP',
          style: TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

// ─── Wallet: coins + VIP ────────────────────────────────────────────────────

class _WalletCard extends ConsumerWidget {
  final User user;
  const _WalletCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(coinBalanceProvider);
    final isVip = user.hasActiveSubscription;
    final ends = user.subscriptionEndsAt;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1724), Color(0xFF2B2012)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _WalletHalf(
                onTap: () => showCoinStoreSheet(context),
                top: Row(
                  children: [
                    const CoinIcon(size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Миний зоос',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                value: balance == null ? '—' : '$balance',
                action: 'Цэнэглэх',
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.white12,
            ),
            Expanded(
              child: _WalletHalf(
                onTap: () => context.go('/vip'),
                top: Row(
                  children: [
                    const Icon(
                      Icons.diamond_rounded,
                      color: DramaColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'VIP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                value: isVip ? 'Идэвхтэй' : 'Идэвхгүй',
                valueColor: isVip ? DramaColors.gold : Colors.white,
                caption: isVip && ends != null
                    ? '${_date(ends)} хүртэл'
                    : 'Бүх анги хязгааргүй',
                action: isVip ? null : 'VIP болох',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _WalletHalf extends StatelessWidget {
  final Widget top;
  final String value;
  final Color valueColor;
  final String? caption;
  final String? action;
  final VoidCallback onTap;
  const _WalletHalf({
    required this.top,
    required this.value,
    required this.onTap,
    this.valueColor = Colors.white,
    this.caption,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            top,
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: DramaColors.muted, fontSize: 12),
              ),
            ],
            const Spacer(),
            if (action != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LemonyBrand.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  action!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ─── Small pieces ───────────────────────────────────────────────────────────

class _VerifyNudge extends StatelessWidget {
  final bool hasPhone;
  const _VerifyNudge({required this.hasPhone});

  @override
  Widget build(BuildContext context) => Material(
    color: DramaColors.gold.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/profile/verify-phone'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              color: DramaColors.gold,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPhone ? 'Дугаараа баталгаажуулаарай' : 'Утсаа холбоорой',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Бүртгэл, зоос, VIP-ээ хамгаалах нэг алхам',
                    style: TextStyle(color: DramaColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DramaColors.gold,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: DramaColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.bookmark_border_rounded,
          color: DramaColors.muted,
          size: 26,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Дуртай драмаа хадгалаад эндээс хурдан олоорой.',
            style: TextStyle(color: DramaColors.muted, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/dramas'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('Үзэх'),
        ),
      ],
    ),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: ColoredBox(
      color: DramaColors.surface,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 0.5,
                indent: 56,
                color: Color(0x14FFFFFF),
              ),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final String? trailing;
  final Color? trailingColor;
  final bool showChevron;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
    this.trailingColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: (color ?? Colors.white).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: c, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  color: trailingColor ?? DramaColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (showChevron && onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: DramaColors.faint,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
