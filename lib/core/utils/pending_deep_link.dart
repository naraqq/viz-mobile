class PendingDeepLink {
  PendingDeepLink._();

  static String? _path;

  static void store(String path) => _path = path;

  static String? consume() {
    final p = _path;
    _path = null;
    return p;
  }

  static bool get hasPending => _path != null;
}
