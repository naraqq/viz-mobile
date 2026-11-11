import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/json_helpers.dart';
import '../../core/providers/auth_provider.dart';
import '../drama/drama_api.dart';

class CheckinDay {
  final int day;
  final int coins;
  final String state; // claimed | today | upcoming
  const CheckinDay(this.day, this.coins, this.state);
}

class WatchTask {
  final int minutes;
  final int coins;
  final String state; // locked | claimable | claimed
  const WatchTask(this.minutes, this.coins, this.state);
}

class RewardsState {
  final int balance;
  final int streak;
  final bool claimedToday;
  final List<CheckinDay> days;
  final int secondsToday;
  final List<WatchTask> tasks;

  const RewardsState({
    required this.balance,
    required this.streak,
    required this.claimedToday,
    required this.days,
    required this.secondsToday,
    required this.tasks,
  });

  int get todayCoins => days
      .firstWhere(
        (d) => d.state == 'today',
        orElse: () => const CheckinDay(0, 0, ''),
      )
      .coins;

  bool get hasSomethingToClaim =>
      !claimedToday || tasks.any((t) => t.state == 'claimable');

  factory RewardsState.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    List<Map<String, dynamic>> l(dynamic v) =>
        v is List ? v.map(m).toList() : const [];
    final c = m(j['checkin']);
    final w = m(j['watch']);
    return RewardsState(
      balance: readInt(j['balance']) ?? 0,
      streak: readInt(c['streak']) ?? 0,
      claimedToday: c['claimed_today'] == true,
      days: l(c['days'])
          .map(
            (d) => CheckinDay(
              readInt(d['day']) ?? 0,
              readInt(d['coins']) ?? 0,
              d['state']?.toString() ?? 'upcoming',
            ),
          )
          .toList(),
      secondsToday: readInt(w['seconds_today']) ?? 0,
      tasks: l(w['tasks'])
          .map(
            (t) => WatchTask(
              readInt(t['minutes']) ?? 0,
              readInt(t['coins']) ?? 0,
              t['state']?.toString() ?? 'locked',
            ),
          )
          .toList(),
    );
  }
}

class RewardsApi {
  final ApiClient _api;
  RewardsApi(this._api);

  Future<RewardsState> state() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.rewards);
      return RewardsState.fromJson(res.data!);
    } on DioException catch (e) {
      throw DramaException(_msg(e, 'Шагналыг ачаалж чадсангүй.'));
    }
  }

  /// Claim today's check-in. Returns (coins won, new state).
  Future<(int, RewardsState)> checkIn() => _claim(ApiEndpoints.rewardsCheckin);

  Future<(int, RewardsState)> claimWatch(int minutes) =>
      _claim(ApiEndpoints.rewardsWatchClaim(minutes));

  Future<(int, RewardsState)> _claim(String path) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(path);
      final d = res.data!;
      final reward = d['reward'] is Map ? d['reward'] as Map : const {};
      return (readInt(reward['coins']) ?? 0, RewardsState.fromJson(d));
    } on DioException catch (e) {
      throw DramaException(_msg(e, 'Шагнал авч чадсангүй.'));
    }
  }

  /// Playback heartbeat for watch tasks. Fire-and-forget.
  Future<void> heartbeat() async {
    try {
      await _api.post<dynamic>(ApiEndpoints.rewardsHeartbeat);
    } catch (_) {}
  }

  static String _msg(DioException e, String fallback) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    return fallback;
  }
}

final rewardsApiProvider = Provider<RewardsApi>(
  (ref) => RewardsApi(ref.read(apiClientProvider)),
);

final rewardsProvider = FutureProvider.autoDispose<RewardsState>(
  (ref) => ref.read(rewardsApiProvider).state(),
);
