import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeCeritaScreen extends StatefulWidget {
  const NativeCeritaScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeCeritaScreen> createState() => _NativeCeritaScreenState();
}

class _NativeCeritaScreenState extends State<NativeCeritaScreen>
    with SingleTickerProviderStateMixin {
  final _api = BtAdminApi();
  late final TabController _tab;
  bool _loading = true;
  List<Map<String, dynamic>> _stories = const [];
  List<Map<String, dynamic>> _reels = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'cerita');
      if (!mounted) return;
      setState(() {
        _stories = (data['stories'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _reels = (data['reels'] as List?)
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

  Future<void> _deleteItem(String kind, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text('Hapus ${kind == 'reel' ? 'Reels' : 'Cerita'}?'),
        content: Text('Konten #$id dan seluruh komentarnya akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await _api.postAction(
        widget.token,
        'cerita_delete',
        {'kind': kind, 'id': id},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AdminColors.emerald),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderasi Cerita & Reels'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          TextButton(
            onPressed: widget.onOpenWeb,
            child: const Text('Web', style: TextStyle(color: AdminColors.gold)),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AdminColors.gold,
          tabs: [
            Tab(text: 'Cerita (${_stories.length})'),
            Tab(text: 'Reels (${_reels.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _buildList(_stories, 'story'),
                _buildList(_reels, 'reel'),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String kind) {
    if (items.isEmpty) {
      return const Center(child: Text('Belum ada konten.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, idx) {
          final item = items[idx];
          final id = (item['id'] ?? '').toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                kind == 'reel'
                    ? Icons.video_library_rounded
                    : Icons.photo_library_rounded,
                color: AdminColors.gold,
              ),
              title: Text(
                (item['author'] ?? 'Anggota').toString(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                '${(item['caption'] ?? '').toString().isEmpty ? "(Tanpa caption)" : item['caption']}\n${item['created_at']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminColors.textSecondary,
                ),
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AdminColors.danger),
                onPressed: () => _deleteItem(kind, id),
              ),
            ),
          );
        },
      ),
    );
  }
}
