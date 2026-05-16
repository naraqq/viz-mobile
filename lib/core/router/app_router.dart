import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_loading_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/genres/genre_content_screen.dart';
import '../../features/genres/genre_list_screen.dart';
import '../../features/update/force_update_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/movies/movie_detail_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/plans/plans_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shows/show_detail_screen.dart';
import '../../shared/widgets/viz_bottom_nav.dart';
import '../models/season.dart';
import '../models/subtitle_track.dart';
import '../providers/app_config_provider.dart';
import '../providers/auth_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = AuthRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth/loading',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // Force update takes highest priority — blocks all navigation.
      if (ref.read(forceUpdateProvider)) {
        return state.matchedLocation == '/force-update' ? null : '/force-update';
      }

      final authState = ref.read(authProvider);
      final isLoadingRoute = state.matchedLocation == '/auth/loading';

      if (authState.isInitializing) {
        return isLoadingRoute ? null : '/auth/loading';
      }

      final isAuth = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login';

      if (isLoadingRoute) return isAuth ? '/' : '/login';
      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        pageBuilder: (context, state, child) => NoTransitionPage(
          key: state.pageKey,
          child: VizBottomNav(child: child),
        ),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/browse',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const BrowseScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const NotificationsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/plans',
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const PlansScreen()),
      ),
      GoRoute(
        path: '/force-update',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const ForceUpdateScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/auth/loading',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const AuthLoadingScreen(),
        ),
      ),
      GoRoute(
        path: '/genres',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const GenreListScreen(),
        ),
      ),
      GoRoute(
        path: '/genres/:slug',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final label = state.uri.queryParameters['label'] ?? slug;
          return NoTransitionPage(
            key: state.pageKey,
            child: GenreContentScreen(slug: slug, label: label),
          );
        },
      ),
      GoRoute(
        path: '/movies/:slug',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return NoTransitionPage(
            key: state.pageKey,
            child: MovieDetailScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/shows/:slug',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return NoTransitionPage(
            key: state.pageKey,
            child: ShowDetailScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return NoTransitionPage(
            key: state.pageKey,
            child: PlayerScreen(
              hlsUrl: extra['hlsUrl'] as String,
              title: extra['title'] as String,
              watchableType: extra['watchableType'] as String,
              watchableId: extra['watchableId'] as int,
              startPosition: extra['startPosition'] as int? ?? 0,
              subtitleTracks: (extra['subtitleTracks'] as List<dynamic>? ?? [])
                  .whereType<SubtitleTrack>()
                  .toList(),
              seriesTitle: extra['seriesTitle'] as String?,
              seasons: (extra['seasons'] as List<dynamic>? ?? [])
                  .whereType<Season>()
                  .toList(),
              episodeProgress:
                  (extra['episodeProgress'] as Map<int, int>?) ?? const {},
              currentEpisodeId: extra['currentEpisodeId'] as int?,
            ),
          );
        },
      ),
    ],
  );
});

class AuthRouterRefreshNotifier extends ChangeNotifier {
  AuthRouterRefreshNotifier(this._ref) {
    _authSub = _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    _updateSub = _ref.listen<bool>(forceUpdateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _authSub;
  late final ProviderSubscription<bool> _updateSub;

  @override
  void dispose() {
    _authSub.close();
    _updateSub.close();
    super.dispose();
  }
}
