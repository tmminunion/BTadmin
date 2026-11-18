import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeBeritaScreen extends StatefulWidget {
  const NativeBeritaScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeBeritaScreen> createState() => _NativeBeritaScreenState();
}

class _NativeBeritaScreenState extends State<NativeBeritaScreen> {
  final _api = BtAdminApi();
  bool _loading = true;
  bool _busy = false;
  bool _autoPush = false;
  String _lastResult = '';
  List<Map<String, dynamic>> _posts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'berita');
      if (!mounted) return;
      setState(() {
        _autoPush = data['auto_push'] == true;
        _lastResult = (data['last_result'] ?? '').toString();
        _posts = (data['posts'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  Future<void> _action(String action, {bool? autoPush}) async {
    setState(() => _busy = true);
    try {
      final msg = await _api.postAction(widget.token, 'berita_action', {
        'action': action,
        if (autoPush != null) 'auto_push': autoPush,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AdminColors.emerald),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AdminColors.danger),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Berita & Blogger Sync'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          TextButton(
            onPressed: widget.onOpenWeb,
            child: const Text('Web', style: TextStyle(color: AdminColors.gold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Auto-Push Notifikasi Berita',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          _lastResult.isNotEmpty
                              ? _lastResult
                              : 'Otomatis kirim FCM saat ada artikel baru',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _autoPush,
                        activeTrackColor: AdminColors.emerald,
                        onChanged: _busy
                            ? null
                            : (v) => _action('toggle_auto', autoPush: v),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _busy ? null : () => _action('sync'),
                                icon: const Icon(Icons.sync_rounded),
                                label: const Text('Sync Blogger'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _action('push_latest'),
                                icon: const Icon(Icons.notifications_active),
                                label: const Text('Push Terbaru'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Artikel Blogger Terbaru',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._posts.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.article_rounded,
                          color: AdminColors.sky),
                      title: Text(
                        (p['title'] ?? 'Tanpa Judul').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        (p['published'] ?? p['url'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AdminColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
