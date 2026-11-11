import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/lemony_logo.dart';
import '../drama/drama_api.dart';
import '../drama/widgets/coin_store.dart';
import '../drama/widgets/drama_widgets.dart';
import 'rewards_api.dart';

/// Daily check-in + watch tasks, shown at the top of the Шагнал tab.
class RewardsSection extends ConsumerStatefulWidget {
  const RewardsSection({super.key});

  @override
  ConsumerState<RewardsSection> createState() => _RewardsSectionState();
}

class _RewardsSectionState extends ConsumerState<RewardsSection> {
  bool _busy = false;

  Future<void> _claim(Future<(int, RewardsState)> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final (coins, state) = await action();
      ref.read(coinBalanceProvider.notifier).state = state.balance;
      ref.invalidate(rewardsProvider);
      if (mounted && coins > 0) {
        HapticFeedback.mediumImpact();
        await showRewardCelebration(context, coins);
      }
    } on DramaException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rewardsProvider);
    final api = ref.read(rewardsApiProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 4),
        child: SkeletonBox(height: 190),
      ),
      // Rewards failing must not hide VIP / coins below.
      error: (_, __) => const SizedBox.shrink(),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CheckinCard(
            state: s,
            busy: _busy,
            onClaim: () => _claim(api.checkIn),
          ),
          const SizedBox(height: 12),
          _WatchTasksCard(
            state: s,
            busy: _busy,
            onClaim: (m) => _claim(() => api.claimWatch(m)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      color: DramaColors.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class _CheckinCard extends StatelessWidget {
  final RewardsState state;
  final bool busy;
  final VoidCallback onClaim;
  const _CheckinCard({
    required this.state,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Өдөр бүрийн шагнал',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (s.streak > 0)
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: LemonyBrand.rose,
                      size: 18,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${s.streak} өдөр дараалан',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < s.days.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  flex: i == 6 ? 14 : 10,
                  child: _DayTile(day: s.days[i], big: i == 6),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: s.claimedToday
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: DramaColors.surface2,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: const Text(
                      'Маргааш дахин ирээрэй',
                      style: TextStyle(
                        color: DramaColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : GradientPill(
                    label: busy
                        ? 'Түр хүлээнэ үү…'
                        : 'Шагнал авах · +${s.todayCoins}',
                    icon: busy ? null : Icons.card_giftcard_rounded,
                    onTap: busy ? null : onClaim,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final CheckinDay day;
  final bool big;
  const _DayTile({required this.day, required this.big});

  @override
  Widget build(BuildContext context) {
    final claimed = day.state == 'claimed';
    final today = day.state == 'today';
    return AspectRatio(
      aspectRatio: big ? 0.98 : 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: claimed ? const Color(0xFF2A2630) : DramaColors.surface2,
          gradient: today
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A1E33), Color(0xFF4A3212)],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: today ? LemonyBrand.amber : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (claimed)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF4ADE80),
                size: 20,
              )
            else
              CoinIcon(size: big ? 24 : 18),
            const SizedBox(height: 4),
            Text(
              '+${day.coins}',
              style: TextStyle(
                color: claimed ? DramaColors.muted : Colors.white,
                fontSize: big ? 14 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            // Shrinks to fit the narrow tile instead of being cut off.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  today ? 'Өнөөдөр' : '${day.day}-р өдөр',
                  maxLines: 1,
                  style: TextStyle(
                    color: today ? LemonyBrand.amber : DramaColors.faint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchTasksCard extends StatelessWidget {
  final RewardsState state;
  final bool busy;
  final ValueChanged<int> onClaim;
  const _WatchTasksCard({
    required this.state,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final watched = state.secondsToday ~/ 60;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Үзэж зоос цуглуул',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'Өнөөдөр $watched мин',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final t in state.tasks)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  CoinIcon(size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.minutes} минут үзэх',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (state.secondsToday / (t.minutes * 60))
                                .clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: DramaColors.surface2,
                            color: t.state == 'claimed'
                                ? DramaColors.faint
                                : LemonyBrand.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 84,
                    height: 34,
                    child: switch (t.state) {
                      'claimable' => GradientPill(
                        label: '+${t.coins}',
                        height: 34,
                        onTap: busy ? null : () => onClaim(t.minutes),
                      ),
                      'claimed' => const Center(
                        child: Text(
                          'Авсан',
                          style: TextStyle(
                            color: DramaColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _ => Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DramaColors.surface2,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Text(
                          '+${t.coins}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "+N зоос" pop-up after a claim.
Future<void> showRewardCelebration(BuildContext context, int coins) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'reward',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) {
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (ctx.mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      });
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 84),
              const SizedBox(height: 14),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LemonyBrand.gradient.createShader(r),
                child: Text(
                  '+$coins зоос',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Түрийвчинд нэмэгдлээ',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (_, a, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}
