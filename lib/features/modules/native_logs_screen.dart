import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeLogsScreen extends StatefulWidget {
  const NativeLogsScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeLogsScreen> createState() => _NativeLogsScreenState();
}

class _NativeLogsScreenState extends State<NativeLogsScreen> {
  final _api = BtAdminApi();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = Uri.encodeQueryComponent(_searchCtrl.text.trim());
      final data = await _api.getJson(widget.token, 'logs?search=$q');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Log Login'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          TextButton(
            onPressed: widget.onOpenWeb,
            child: const Text('Web', style: TextStyle(color: AdminColors.gold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Cari noreg, nama, via, atau device...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _load,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _items.length,
                      itemBuilder: (_, idx) {
                        final log = _items[idx];
                        final ok = log['success'] == true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              ok
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color:
                                  ok ? AdminColors.emerald : AdminColors.danger,
                            ),
                            title: Text(
                              '${log['nama']} (${log['noreg']})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              '${log['via']} • ${log['device']}\n${log['created_at']}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                            isThreeLine: true,
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
