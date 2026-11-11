import '../../core/models/json_helpers.dart';
import '../../core/models/stream_video.dart';

String? _text(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty) ? null : t;
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : const [];

/// A drama as shown on posters and in grids.
class DramaCard {
  final int id;
  final String slug;
  final String title;
  final String? overview;
  final String? posterUrl; // vertical 2:3 / 9:16
  final String? backdropUrl;
  final int episodes;
  final int freeEpisodes;
  final bool isFree;
  final bool isNew;
  final bool isFeatured;
  final List<String> genres;

  const DramaCard({
    required this.id,
    required this.slug,
    required this.title,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.episodes = 0,
    this.freeEpisodes = 0,
    this.isFree = false,
    this.isNew = false,
    this.isFeatured = false,
    this.genres = const [],
  });

  factory DramaCard.fromJson(Map<String, dynamic> j) => DramaCard(
    id: readInt(j['id']) ?? 0,
    slug: j['slug']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    // Prefer the Mongolian synopsis; full records send both, list cards send one.
    overview: _text(j['overview_mn']) ?? _text(j['overview']),
    posterUrl: (j['vertical_poster_url'] ?? j['poster_url'])?.toString(),
    backdropUrl: j['backdrop_url']?.toString(),
    episodes: readInt(j['number_of_episodes']) ?? 0,
    freeEpisodes: readInt(j['free_episodes']) ?? 0,
    isFree: j['is_free'] == true,
    isNew: j['is_new'] == true,
    isFeatured: j['is_featured'] == true,
    genres: _list(
      j['genres'],
    ).map((g) => g is Map ? '${g['name']}' : '$g').toList(),
  );
}

/// One episode in a drama's episode list.
class DramaEpisode {
  final int id;
  final int number;
  final String? name;
  final String? stillUrl;
  final bool isLocked;
  final int? coinPrice;

  const DramaEpisode({
    required this.id,
    required this.number,
    this.name,
    this.stillUrl,
    this.isLocked = false,
    this.coinPrice,
  });

  DramaEpisode copyWith({bool? isLocked}) => DramaEpisode(
    id: id,
    number: number,
    name: name,
    stillUrl: stillUrl,
    isLocked: isLocked ?? this.isLocked,
    coinPrice: coinPrice,
  );

  factory DramaEpisode.fromJson(Map<String, dynamic> j) => DramaEpisode(
    id: readInt(j['id']) ?? 0,
    number: readInt(j['episode_number']) ?? 0,
    name: j['name']?.toString(),
    stillUrl: j['still_url']?.toString(),
    isLocked: j['is_locked'] == true,
    coinPrice: readInt(j['coin_price']),
  );
}

class AccessSummary {
  final bool isVip;
  final int coinBalance;
  final int freeEpisodes;
  final int? episodeCoinPrice;

  const AccessSummary({
    this.isVip = false,
    this.coinBalance = 0,
    this.freeEpisodes = 0,
    this.episodeCoinPrice,
  });

  factory AccessSummary.fromJson(Map<String, dynamic> j) => AccessSummary(
    isVip: j['is_vip'] == true,
    coinBalance: readInt(j['coin_balance']) ?? 0,
    freeEpisodes: readInt(j['free_episodes']) ?? 0,
    episodeCoinPrice: readInt(j['episode_coin_price']),
  );
}

/// GET /shows/{slug}: the drama, all its episodes in order, and the viewer's state.
class DramaDetail {
  final DramaCard drama;
  final List<DramaEpisode> episodes;
  final Map<int, int> progress; // episode id → seconds
  final AccessSummary access;
  final bool liked;
  final bool saved;
  final int likes;

  /// Server's resume point: last watched episode, or the next one if it was finished.
  final int? resumeEpisodeId;

  const DramaDetail({
    required this.drama,
    required this.episodes,
    this.progress = const {},
    this.access = const AccessSummary(),
    this.liked = false,
    this.saved = false,
    this.likes = 0,
    this.resumeEpisodeId,
  });

  /// Index to open the player at: the server's resume point, else (older servers) the
  /// furthest episode with unfinished progress, else the first episode.
  int get resumeIndex {
    if (resumeEpisodeId != null) {
      final i = episodes.indexWhere((e) => e.id == resumeEpisodeId);
      if (i >= 0) return i;
    }
    final e = resumeEpisode;
    return e == null ? 0 : episodes.indexOf(e).clamp(0, episodes.length);
  }

  /// The episode to resume: the last one with saved progress, else the first.
  DramaEpisode? get resumeEpisode {
    if (episodes.isEmpty) return null;
    for (final e in episodes.reversed) {
      if (progress.containsKey(e.id)) return e;
    }
    return episodes.first;
  }

  factory DramaDetail.fromJson(Map<String, dynamic> j) {
    final show = _map(j['show']);
    final episodes = <DramaEpisode>[];
    final seasons = _list(show['seasons']).map(_map).toList()
      ..sort(
        (a, b) => (readInt(a['season_number']) ?? 0).compareTo(
          readInt(b['season_number']) ?? 0,
        ),
      );
    for (final s in seasons) {
      final eps =
          _list(
              s['episodes'],
            ).map((e) => DramaEpisode.fromJson(_map(e))).toList()
            ..sort((a, b) => a.number.compareTo(b.number));
      episodes.addAll(eps);
    }
    final progress = <int, int>{};
    final rawProgress = j['episode_progress'];
    if (rawProgress is Map) {
      rawProgress.forEach((k, v) {
        final id = int.tryParse('$k');
        final sec = readInt(v);
        if (id != null && sec != null) progress[id] = sec;
      });
    }
    final eng = _map(j['engagement']);
    return DramaDetail(
      drama: DramaCard.fromJson(show),
      episodes: episodes,
      progress: progress,
      access: AccessSummary.fromJson(_map(j['access'])),
      liked: eng['liked'] == true,
      saved: eng['saved'] == true,
      likes: readInt(eng['likes']) ?? 0,
      resumeEpisodeId: readInt(_map(j['resume'])['episode_id']),
    );
  }
}

/// GET /episodes/{id}/play: either a stream, or paywall info (402).
class EpisodePlay {
  final DramaEpisode episode;
  final bool locked;
  final String? message;
  final StreamVideo? stream;
  final int positionSeconds;
  final AccessSummary access;

  const EpisodePlay({
    required this.episode,
    required this.locked,
    this.message,
    this.stream,
    this.positionSeconds = 0,
    this.access = const AccessSummary(),
  });

  String? get url => stream?.hlsUrl ?? stream?.playbackUrl;

  factory EpisodePlay.fromJson(Map<String, dynamic> j) => EpisodePlay(
    episode: DramaEpisode.fromJson(_map(j['episode'])),
    locked: j['locked'] == true,
    message: j['message']?.toString(),
    stream: j['stream_video'] is Map
        ? StreamVideo.fromJson(_map(j['stream_video']))
        : null,
    positionSeconds: readInt(j['position_seconds']) ?? 0,
    access: AccessSummary.fromJson(_map(j['access'])),
  );
}

/// One item of the Reels feed: a drama and its first episode.
class FeedItem {
  final DramaCard drama;
  final DramaEpisode episode;
  final StreamVideo? stream;

  const FeedItem({required this.drama, required this.episode, this.stream});

  factory FeedItem.fromJson(Map<String, dynamic> j) {
    final ep = _map(j['episode']);
    return FeedItem(
      drama: DramaCard.fromJson(_map(j['show'])),
      episode: DramaEpisode.fromJson(ep),
      stream: ep['stream_video'] is Map
          ? StreamVideo.fromJson(_map(ep['stream_video']))
          : null,
    );
  }
}

class ContinueItem {
  final DramaCard drama;
  final int episodeNumber;
  final int progress; // 0–100

  /// Exact episode to open (null from older servers: the player then resumes on its own).
  final int? episodeId;

  const ContinueItem(
    this.drama,
    this.episodeNumber,
    this.progress, {
    this.episodeId,
  });

  /// Player route that opens exactly this episode.
  String get watchPath => episodeId == null
      ? '/drama/${drama.slug}/watch'
      : '/drama/${drama.slug}/watch?ep=$episodeId';

  factory ContinueItem.fromJson(Map<String, dynamic> j) => ContinueItem(
    DramaCard.fromJson(_map(j['drama'])),
    readInt(j['episode_number']) ?? 1,
    readInt(j['progress']) ?? 0,
    episodeId: readInt(j['episode_id']),
  );
}

/// One section of the drama home (same builder as the web home).
class HomeSection {
  final String type; // hero | continue | top10 | row | banner | genre_tabs
  final String style;
  final String title;
  final List<DramaCard> items;
  final List<ContinueItem> continueItems;
  final List<({String genre, String title, List<DramaCard> items})> tabs;
  final String? bannerSubtitle;
  final String? bannerCta;

  const HomeSection({
    required this.type,
    required this.style,
    required this.title,
    this.items = const [],
    this.continueItems = const [],
    this.tabs = const [],
    this.bannerSubtitle,
    this.bannerCta,
  });

  factory HomeSection.fromJson(Map<String, dynamic> j) {
    final type = j['type']?.toString() ?? 'row';
    final banner = _map(j['banner']);
    return HomeSection(
      type: type,
      style: j['style']?.toString() ?? 'row',
      title: j['title']?.toString() ?? '',
      items: type == 'continue'
          ? const []
          : _list(j['items']).map((e) => DramaCard.fromJson(_map(e))).toList(),
      continueItems: type == 'continue'
          ? _list(
              j['items'],
            ).map((e) => ContinueItem.fromJson(_map(e))).toList()
          : const [],
      tabs: _list(j['tabs']).map((t) {
        final m = _map(t);
        return (
          genre: m['genre']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          items: _list(
            m['items'],
          ).map((e) => DramaCard.fromJson(_map(e))).toList(),
        );
      }).toList(),
      bannerSubtitle: banner['subtitle']?.toString(),
      bannerCta: banner['cta']?.toString(),
    );
  }
}

class CoinPackage {
  final int id;
  final String name;
  final int coins;
  final int bonus;
  final double price;
  final String? badge;

  const CoinPackage({
    required this.id,
    required this.name,
    required this.coins,
    this.bonus = 0,
    required this.price,
    this.badge,
  });

  factory CoinPackage.fromJson(Map<String, dynamic> j) => CoinPackage(
    id: readInt(j['id']) ?? 0,
    name: j['name']?.toString() ?? '',
    coins: readInt(j['coins']) ?? 0,
    bonus: readInt(j['bonus_coins']) ?? 0,
    price: readDouble(j['price_mnt']) ?? 0,
    badge: j['badge']?.toString(),
  );
}
