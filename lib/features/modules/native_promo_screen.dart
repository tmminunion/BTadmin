import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativePromoScreen extends StatefulWidget {
  const NativePromoScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativePromoScreen> createState() => _NativePromoScreenState();
}

class _NativePromoScreenState extends State<NativePromoScreen> {
  final _api = BtAdminApi();
  final _verCtrl = TextEditingController();
  final _buildCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _updateEnabled = false;
  bool _forceUpdate = false;
  List<Map<String, dynamic>> _promos = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _verCtrl.dispose();
    _buildCtrl.dispose();
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'promo');
      if (!mounted) return;
      final upd = (data['app_update'] as Map<String, dynamic>?) ?? const {};
      _verCtrl.text = (upd['latest_version'] ?? '10.1.0').toString();
      _buildCtrl.text = (upd['latest_build'] ?? '60').toString();
      _titleCtrl.text = (upd['title'] ?? 'Update Aplikasi Tersedia').toString();
      _msgCtrl.text = (upd['message'] ?? '').toString();
      setState(() {
        _updateEnabled = upd['enabled'] == true;
        _forceUpdate = upd['force_update'] == true;
        _promos = (data['promos'] as List?)
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

  Future<void> _saveUpdate() async {
    setState(() => _saving = true);
    try {
      final msg = await _api.postAction(widget.token, 'promo_save_update', {
        'enabled': _updateEnabled,
        'force_update': _forceUpdate,
        'latest_version': _verCtrl.text.trim(),
        'latest_build': int.tryParse(_buildCtrl.text.trim()) ?? 60,
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePromo(String id) async {
    try {
      final msg = await _api.postAction(widget.token, 'promo_toggle', {'id': id});
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

  Future<void> _deletePromo(String id) async {
    try {
      final msg = await _api.postAction(widget.token, 'promo_delete', {'id': id});
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
        title: const Text('Promo & Update APK'),
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
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Konfigurasi Update APK Bungtemin',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Aktifkan Notifikasi Update'),
                          value: _updateEnabled,
                          activeTrackColor: AdminColors.emerald,
                          onChanged: (v) => setState(() => _updateEnabled = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Paksa Update (Force Update)'),
                          value: _forceUpdate,
                          activeTrackColor: AdminColors.danger,
                          onChanged: (v) => setState(() => _forceUpdate = v),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _verCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Latest Version'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _buildCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Latest Build'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _titleCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Judul Update'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _msgCtrl,
                          maxLines: 2,
                          decoration:
                              const InputDecoration(labelText: 'Pesan Update'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _saveUpdate,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'Menyimpan...' : 'Simpan Update'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Daftar Banner Promo (${_promos.length})',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._promos.map((p) {
                  final id = (p['id'] ?? '').toString();
                  final active = p['active'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        (p['title'] ?? id).toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        (p['body'] ?? p['subtitle'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AdminColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: active,
                            activeTrackColor: AdminColors.emerald,
                            onChanged: (_) => _togglePromo(id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AdminColors.danger),
                            onPressed: () => _deletePromo(id),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
