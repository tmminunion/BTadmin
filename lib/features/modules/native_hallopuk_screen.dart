import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

/// Native Hallo PUK (/btapi/AdminApp/hallopuk) di BTadmin.
class NativeHallopukScreen extends StatefulWidget {
  const NativeHallopukScreen({super.key, required this.token});
  final String token;

  @override
  State<NativeHallopukScreen> createState() => _NativeHallopukScreenState();
}

class _NativeHallopukScreenState extends State<NativeHallopukScreen> {
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
      final data = await _api.getJson(widget.token, 'hallopuk?status=$_filter');
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

  Future<void> _action(int id, String act, {String? status, String? note}) async {
    try {
      final msg = await _api.postAction(widget.token, 'hallopuk_action', {
        'id': id,
        'action': act,
        if (status != null) 'status': status,
        if (note != null) 'admin_note': note,
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

  void _openReplySheet(Map<String, dynamic> item) {
    final id = int.tryParse('${item['id'] ?? 0}') ?? 0;
    String status = '${item['status'] ?? 'diproses'}';
    if (!['baru', 'diproses', 'selesai'].contains(status)) status = 'diproses';
    final noteCtrl = TextEditingController(text: '${item['admin_note'] ?? ''}');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tindak Lanjut ${item['ticket_code'] ?? '#$id'}',
                style: const TextStyle(
                  color: AdminColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final (v, lbl) in [
                    ('baru', 'Baru'),
                    ('diproses', 'Diproses'),
                    ('selesai', 'Selesai'),
                  ])
                    ChoiceChip(
                      label: Text(lbl),
                      selected: status == v,
                      onSelected: (_) => setModalState(() => status = v),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                style: const TextStyle(color: AdminColors.ink, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Tanggapan / Catatan PUK',
                  labelStyle: const TextStyle(color: AdminColors.muted),
                  filled: true,
                  fillColor: AdminColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _action(id, 'update', status: status, note: noteCtrl.text.trim());
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String st) {
    switch (st) {
      case 'selesai':
        return AdminColors.emerald;
      case 'diproses':
        return AdminColors.cyan;
      default:
        return AdminColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Hallo PUK (Aspirasi)'),
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
                          'Belum ada tiket Hallo PUK.',
                          style: TextStyle(color: AdminColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (_, idx) {
                            final it = _items[idx];
                            final id = int.tryParse('${it['id'] ?? 0}') ?? 0;
                            final st = '${it['status'] ?? 'baru'}';
                            final color = _statusColor(st);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AdminColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AdminColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${it['ticket_code'] ?? '#$id'} · ${it['kategori_label'] ?? it['kategori'] ?? 'Lapor'}',
                                          style: const TextStyle(
                                            color: AdminColors.cyan,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          st.toUpperCase(),
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${it['judul'] ?? '-'}',
                                    style: const TextStyle(
                                      color: AdminColors.ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${it['isi'] ?? ''}',
                                    style: const TextStyle(
                                      color: AdminColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${it['nama'] ?? 'Anggota'} (${it['noreg'] ?? '-'}) · ${it['bagian'] ?? '-'} · ${it['created_at'] ?? ''}',
                                    style: const TextStyle(
                                      color: AdminColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if ('${it['admin_note'] ?? ''}'.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tanggapan PUK: ${it['admin_note']}',
                                      style: const TextStyle(
                                        color: AdminColors.emerald,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _openReplySheet(it),
                                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                                        label: const Text('Proses / Balas'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _action(id, 'delete'),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: AdminColors.danger,
                                        ),
                                        label: const Text(
                                          'Hapus',
                                          style: TextStyle(color: AdminColors.danger),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
