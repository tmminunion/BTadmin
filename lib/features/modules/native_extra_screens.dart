import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../models/admin_models.dart';
import '../../services/bt_admin_api.dart';

/// 1. Native Saran Aplikasi (/btapi/AdminApp/feedback)
class NativeFeedbackScreen extends StatefulWidget {
  const NativeFeedbackScreen({super.key, required this.token});
  final String token;

  @override
  State<NativeFeedbackScreen> createState() => _NativeFeedbackScreenState();
}

class _NativeFeedbackScreenState extends State<NativeFeedbackScreen> {
  final _api = BtAdminApi();
  bool _loading = true;
  String _filter = '';
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'feedback?status=$_filter');
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List?)
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

  Future<void> _action(int id, String act, {String? status}) async {
    try {
      final msg = await _api.postAction(widget.token, 'feedback_action', {
        'id': id,
        'action': act,
        if (status != null) 'status': status,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Saran Aplikasi'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                for (final (val, lbl) in [
                  ('', 'Semua'),
                  ('baru', 'Baru'),
                  ('diproses', 'Diproses'),
                  ('selesai', 'Selesai'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(lbl),
                      selected: _filter == val,
                      onSelected: (_) {
                        setState(() => _filter = val);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada saran masuk.',
                          style: TextStyle(color: AdminColors.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (_, idx) {
                            final item = _items[idx];
                            final id = int.tryParse('${item['id']}') ?? 0;
                            final st = '${item['status'] ?? 'baru'}';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item['nama'] ?? 'Guest'} (${item['category'] ?? 'UX'})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: st == 'selesai'
                                                ? AdminColors.emerald
                                                    .withValues(alpha: 0.16)
                                                : const Color(0xFFF59E0B)
                                                    .withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            st.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: st == 'selesai'
                                                  ? AdminColors.emerald
                                                  : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${item['message'] ?? ''}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${item['app_version'] ?? ''} • ${item['created_at'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AdminColors.textSecondary,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.edit_note_rounded,
                                                size: 20,
                                              ),
                                              onSelected: (v) => _action(
                                                id,
                                                'update',
                                                status: v,
                                              ),
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'baru',
                                                  child: Text('Tandai Baru'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'diproses',
                                                  child:
                                                      Text('Tandai Diproses'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'selesai',
                                                  child: Text('Tandai Selesai'),
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 19,
                                                color: AdminColors.danger,
                                              ),
                                              onPressed: () =>
                                                  _action(id, 'delete'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// 2. Native Menu Situs Web (/btapi/AdminApp/menus)
class NativeMenusScreen extends StatefulWidget {
  const NativeMenusScreen({super.key, required this.token});
  final String token;

  @override
  State<NativeMenusScreen> createState() => _NativeMenusScreenState();
}

class _NativeMenusScreenState extends State<NativeMenusScreen> {
  final _api = BtAdminApi();
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'menus');
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List?)
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

  Future<void> _toggle(int id) async {
    try {
      final msg =
          await _api.postAction(widget.token, 'menu_toggle', {'id': id});
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Menu Situs Web'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (_, idx) {
                  final m = _items[idx];
                  final id = int.tryParse('${m['id']}') ?? 0;
                  final active = m['is_active'] == 1 || m['is_active'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      value: active,
                      onChanged: (_) => _toggle(id),
                      title: Text(
                        '${m['title'] ?? m['label'] ?? 'Menu'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${m['url'] ?? '-'} • ${m['placement'] ?? 'header'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// 3. Native Analitik (/btapi/AdminApp/analytics)
class NativeAnalyticsScreen extends StatefulWidget {
  const NativeAnalyticsScreen({super.key, required this.token});
  final String token;

  @override
  State<NativeAnalyticsScreen> createState() => _NativeAnalyticsScreenState();
}

class _NativeAnalyticsScreenState extends State<NativeAnalyticsScreen> {
  final _api = BtAdminApi();
  bool _loading = true;
  Map<String, dynamic> _stats = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'analytics');
      if (!mounted) return;
      setState(() {
        _stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
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

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Total User Terdaftar', '${_stats['users_total'] ?? 0}', Icons.people_rounded, AdminColors.sky),
      ('Login 7 Hari Terakhir', '${_stats['logins_7d'] ?? 0}', Icons.login_rounded, AdminColors.emerald),
      ('Antrean WA Aktif', '${_stats['wa_pending'] ?? 0}', Icons.chat_rounded, const Color(0xFFF59E0B)),
      ('Saran App Baru', '${_stats['feedback_baru'] ?? 0}', Icons.comment_rounded, AdminColors.indigo),
      ('Total Meeting', '${_stats['meetings_total'] ?? 0}', Icons.event_rounded, AdminColors.gold),
    ];

    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Analitik & Statistik'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final (title, val, icon, color) in cards)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.16),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(title, style: const TextStyle(fontSize: 13)),
                        trailing: Text(
                          val,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: const Text('Environment Server'),
                      subtitle: Text(
                        'PHP ${_stats['php_version'] ?? '-'} • ${_stats['server_time'] ?? '-'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 4. Native Module Info untuk modul utilitas/sistem (tanpa WebView)
class NativeSystemModuleScreen extends StatelessWidget {
  const NativeSystemModuleScreen({super.key, required this.module});
  final AdminModuleItem module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(title: Text(module.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.gold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    module.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    module.desc,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AdminColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AdminColors.emerald,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modul sistem (${module.key}) berjalan tanpa WebView di aplikasi mobile.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
