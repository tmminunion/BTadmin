import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeUsersScreen extends StatefulWidget {
  const NativeUsersScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeUsersScreen> createState() => _NativeUsersScreenState();
}

class _NativeUsersScreenState extends State<NativeUsersScreen> {
  final _api = BtAdminApi();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String _filter = '';
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
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

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final q = Uri.encodeQueryComponent(_searchCtrl.text.trim());
      final f = Uri.encodeQueryComponent(_filter);
      final data = await _api.getJson(
        widget.token,
        'users?page=$page&search=$q&filter=$f',
      );
      if (!mounted) return;
      final list = (data['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      setState(() {
        _page = page;
        _total = int.tryParse((data['total'] ?? '0').toString()) ?? 0;
        _hasMore = data['has_more'] == true;
        _items = list;
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

  Future<void> _editUser([Map<String, dynamic>? item]) async {
    final noregCtrl =
        TextEditingController(text: (item?['noreg'] ?? '').toString());
    final emailCtrl =
        TextEditingController(text: (item?['email'] ?? '').toString());
    final waCtrl =
        TextEditingController(text: (item?['wa_number'] ?? '').toString());
    final isNew = item == null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(isNew ? 'Tambah User' : 'Edit ${item['nama']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noregCtrl,
              readOnly: !isNew,
              decoration: const InputDecoration(labelText: 'Noreg'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: waCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor WhatsApp'),
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
    );
    if (ok != true) return;
    try {
      final msg = await _api.postAction(widget.token, 'user_save', {
        'noreg': noregCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'wa_number': waCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AdminColors.emerald),
      );
      _load(page: _page);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> item) async {
    final noreg = (item['noreg'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Text('Hapus User?'),
        content: Text('Yakin ingin menghapus akun $noreg (${item['nama']})?'),
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
      final msg = await _api
          .postAction(widget.token, 'user_delete', {'noreg': noreg});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AdminColors.emerald),
      );
      _load(page: _page);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AdminColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('', 'Semua'),
      ('sso', 'SSO'),
      ('nosso', 'Belum SSO'),
      ('nowa', 'No WA'),
      ('noemail', 'No Email'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengguna ($_total)'),
        actions: [
          IconButton(
            tooltip: 'Tambah User',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _editUser(),
          ),
          TextButton(
            onPressed: widget.onOpenWeb,
            child: const Text('Web', style: TextStyle(color: AdminColors.gold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _load(page: 1),
              decoration: InputDecoration(
                hintText: 'Cari noreg, nama, email, atau nomor WA...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => _load(page: 1),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final (key, label) = filters[idx];
                return ChoiceChip(
                  label: Text(label),
                  selected: _filter == key,
                  selectedColor: AdminColors.gold.withValues(alpha: 0.25),
                  onSelected: (_) {
                    setState(() => _filter = key);
                    _load(page: 1);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _load(page: _page),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + 1,
                      itemBuilder: (_, idx) {
                        if (idx == _items.length) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _page > 1
                                    ? () => _load(page: _page - 1)
                                    : null,
                                child: const Text('Sebelumnya'),
                              ),
                              Text('Halaman $_page',
                                  style: const TextStyle(fontSize: 12)),
                              TextButton(
                                onPressed: _hasMore
                                    ? () => _load(page: _page + 1)
                                    : null,
                                child: const Text('Berikutnya'),
                              ),
                            ],
                          );
                        }
                        final u = _items[idx];
                        final hasSso = u['has_sso'] == true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (hasSso
                                      ? AdminColors.emerald
                                      : AdminColors.border)
                                  .withValues(alpha: 0.25),
                              child: Icon(
                                hasSso
                                    ? Icons.verified_user_rounded
                                    : Icons.person_outline_rounded,
                                color: hasSso
                                    ? AdminColors.emerald
                                    : AdminColors.textSecondary,
                              ),
                            ),
                            title: Text(
                              '${u['nama']} (${u['noreg']})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              'WA: ${u['wa_number'].toString().isEmpty ? "-" : u['wa_number']}\nEmail: ${u['email'].toString().isEmpty ? "-" : u['email']}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _editUser(u);
                                if (v == 'del') _deleteUser(u);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'del',
                                  child: Text('Hapus',
                                      style:
                                          TextStyle(color: AdminColors.danger)),
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
