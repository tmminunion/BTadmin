import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeKalenderScreen extends StatefulWidget {
  const NativeKalenderScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeKalenderScreen> createState() => _NativeKalenderScreenState();
}

class _NativeKalenderScreenState extends State<NativeKalenderScreen> {
  final _api = BtAdminApi();
  bool _loading = true;
  String _cacheKey = '';
  List<Map<String, dynamic>> _overrides = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(
        widget.token,
        'kalender?year=${DateTime.now().year}',
      );
      if (!mounted) return;
      setState(() {
        _cacheKey = (data['cache_key'] ?? '').toString();
        _overrides = (data['overrides'] as List?)
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

  Future<void> _addOverride() async {
    final dateCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String color = '2';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AdminColors.surface,
          title: const Text('Tambah / Ubah Tanggal Kalender'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tanggal (YYYY-MM-DD)',
                  hintText: '2026-12-25',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: color,
                dropdownColor: AdminColors.card,
                decoration: const InputDecoration(labelText: 'Jenis Hari'),
                items: const [
                  DropdownMenuItem(value: '2', child: Text('Libur / Cuti (Merah)')),
                  DropdownMenuItem(value: '1', child: Text('Hari Kerja Khusus')),
                  DropdownMenuItem(value: '0', child: Text('Masuk Normal')),
                ],
                onChanged: (v) => setS(() => color = v ?? '2'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Judul Singkat'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Keterangan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final msg = await _api.postAction(widget.token, 'kalender_save', {
        'date': dateCtrl.text.trim(),
        'date_color': color,
        'note': noteCtrl.text.trim(),
        'description': descCtrl.text.trim(),
      });
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

  Future<void> _refreshCacheKey() async {
    try {
      final msg =
          await _api.postAction(widget.token, 'kalender_refresh_key', {});
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

  Future<void> _deleteOverride(String dateKey) async {
    try {
      final msg = await _api
          .postAction(widget.token, 'kalender_delete', {'date': dateKey});
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
        title: const Text('Kalender Kerja & Libur'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addOverride),
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
                  child: ListTile(
                    leading: const Icon(Icons.key_rounded, color: AdminColors.gold),
                    title: Text('Cache Key: $_cacheKey',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text(
                      'Ubah key agar aplikasi member langsung refresh kalender',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    trailing: ElevatedButton(
                      onPressed: _refreshCacheKey,
                      child: const Text('Bump'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Daftar Override Tanggal (${_overrides.length})',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._overrides.map((o) {
                  final dk = (o['date_key'] ?? '').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.event_rounded,
                          color: AdminColors.sky),
                      title: Text(
                        '$dk — ${(o['note'] ?? '').toString()}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        (o['description'] ?? '').toString(),
                        style: const TextStyle(
                            fontSize: 12, color: AdminColors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AdminColors.danger),
                        onPressed: () => _deleteOverride(dk),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
