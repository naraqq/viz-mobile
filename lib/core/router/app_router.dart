import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_loading_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/movies/movie_detail_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/plans/plans_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shows/show_detail_screen.dart';
import '../../shared/widgets/viz_bottom_nav.dart';
import '../models/season.dart';
import '../models/subtitle_track.dart';
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
      final authState = ref.read(authProvider);
      final isLoadingRoute = state.matchedLocation == '/auth/loading';

      if (authState.isInitializing) {
        return isLoadingRoute ? null : '/auth/loading';
      }

      final isAuth = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

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
            pageBuilder: (context, state) {
              final query = state.uri.queryParameters;
              return NoTransitionPage(
                key: state.pageKey,
                child: BrowseScreen(
                  initialSearch: query['search'],
                  initialGenre: query['genre'],
                  initialGenreLabel: query['genreLabel'],
                  initialSort: query['sort'],
                  initialType: query['type'],
                ),
              );
            },
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfileScreen(),
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
        path: '/register',
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const RegisterScreen()),
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
    _subscription = _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
