import 'dart:async';

import 'package:app_links/app_links.dart';

/// Menangani Android App Links (https://bungtemin.net/btadmin/...) dan
/// custom scheme (btadmin://...) agar tautan dari WhatsApp langsung membuka
/// modul tujuan di BTadmin tanpa melalui browser.
class AdminDeepLinkService {
  AdminDeepLinkService._();
  static final AdminDeepLinkService instance = AdminDeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final _controller = StreamController<Uri>.broadcast();
  StreamSubscription<Uri>? _sub;
  Uri? _pendingLaunchUri;
  bool _initialized = false;

  Stream<Uri> get onUri => _controller.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && _isSupportedUri(initial)) {
        _pendingLaunchUri = initial;
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (_isSupportedUri(uri)) {
          _controller.add(uri);
        }
      },
      onError: (_) {},
    );
  }

  Uri? consumePendingUri() {
    final u = _pendingLaunchUri;
    _pendingLaunchUri = null;
    return u;
  }

  static bool _isSupportedUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'btadmin') return true;
    if ((scheme == 'https' || scheme == 'http') &&
        uri.host.toLowerCase() == 'bungtemin.net' &&
        uri.path.toLowerCase().startsWith('/btadmin')) {
      return true;
    }
    return false;
  }

  /// Ekstrak key modul & sub-path dari https://bungtemin.net/btadmin/<module>/<rest>
  static ({String key, String path}) resolveTarget(Uri uri) {
    final segments = <String>[];
    if (uri.scheme.toLowerCase() == 'btadmin') {
      if (uri.host.isNotEmpty) segments.add(uri.host);
      segments.addAll(uri.pathSegments.where((s) => s.isNotEmpty));
    } else {
      final raw = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (raw.isNotEmpty && raw.first.toLowerCase() == 'btadmin') {
        segments.addAll(raw.skip(1));
      } else {
        segments.addAll(raw);
      }
    }
    if (segments.isEmpty) return (key: 'home', path: '/adminpanel');
    final key = segments.first.toLowerCase();
    final path = '/adminpanel/${segments.join('/')}';
    return (key: key, path: path);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
