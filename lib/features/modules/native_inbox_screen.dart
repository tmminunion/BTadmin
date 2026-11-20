import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeInboxScreen extends StatefulWidget {
  const NativeInboxScreen({
    super.key,
    required this.token,
    this.onOpenWeb,
  });

  final String token;
  final VoidCallback? onOpenWeb;

  @override
  State<NativeInboxScreen> createState() => _NativeInboxScreenState();
}

class _NativeInboxScreenState extends State<NativeInboxScreen>
    with SingleTickerProviderStateMixin {
  final _api = BtAdminApi();
  late final TabController _tab;

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _items = const [];

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  final _attUrlCtrl = TextEditingController();
  final _attLabelCtrl = TextEditingController();
  final _actionLabelCtrl = TextEditingController();

  String _category = 'pengumuman';
  String _targetGroup = 'all';
  bool _sendFcm = false;
  final List<_FormFieldDraft> _fields = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _customCtrl.dispose();
    _attUrlCtrl.dispose();
    _attLabelCtrl.dispose();
    _actionLabelCtrl.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AdminColors.danger : AdminColors.emerald,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'inbox_list');
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
      _snack('$e', isError: true);
    }
  }

  Future<void> _sendBroadcast() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('Judul broadcast wajib diisi.', isError: true);
      return;
    }
    final schema = _fields
        .where((f) => f.labelCtrl.text.trim().isNotEmpty)
        .map((f) => f.toJson())
        .toList();

    setState(() => _saving = true);
    try {
      final msg = await _api.postAction(widget.token, 'inbox_save', {
        'title': title,
        'body': _bodyCtrl.text.trim(),
        'category': _category,
        'target_group': _targetGroup,
        'target_noregs': _customCtrl.text.trim(),
        'attachment_url': _attUrlCtrl.text.trim(),
        'attachment_label': _attLabelCtrl.text.trim(),
        'action_label': _actionLabelCtrl.text.trim(),
        'form_schema': schema,
        'send_fcm': _sendFcm,
      });
      _snack(msg);
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _customCtrl.clear();
      _attUrlCtrl.clear();
      _attLabelCtrl.clear();
      _actionLabelCtrl.clear();
      for (final f in _fields) {
        f.dispose();
      }
      setState(() => _fields.clear());
      _tab.animateTo(0);
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(int id) async {
    try {
      final msg = await _api.postAction(widget.token, 'inbox_toggle', {'id': id});
      _snack(msg);
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Broadcast #$id?'),
        content: const Text('Semua data respons anggota untuk broadcast ini juga akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await _api.postAction(widget.token, 'inbox_delete', {'id': id});
      _snack(msg);
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _showResponses(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id']}') ?? 0;
    if (id <= 0) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: _api.getJson(widget.token, 'inbox_responses?id=$id'),
        builder: (_, snap) {
          final rows = (snap.data?['items'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Respons: ${item['title'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : rows.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada anggota yang membaca/mengisi.',
                                  style: TextStyle(color: AdminColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(14),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) => const Divider(height: 12),
                                itemBuilder: (_, i) {
                                  final r = rows[i];
                                  final ans = r['answers'];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${r['noreg']} • ${r['nama'] ?? '-'}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Baca: ${r['read_at'] ?? '-'} • Konfirmasi: ${r['confirmed_at'] ?? '-'}',
                                        style: const TextStyle(fontSize: 11.5, color: AdminColors.textSecondary),
                                      ),
                                      if (ans is Map && ans.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          ans.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
                                          style: const TextStyle(fontSize: 12, color: AdminColors.sky),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Broadcast Inbox App'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AdminColors.gold,
          tabs: const [
            Tab(text: 'Riwayat & Respons'),
            Tab(text: 'Buat Broadcast'),
          ],
        ),
        actions: [
          if (widget.onOpenWeb != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded),
              onPressed: widget.onOpenWeb,
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildListTab(),
          _buildCreateTab(),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(
        child: Text('Belum ada broadcast inbox.', style: TextStyle(color: AdminColors.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _items.length,
        itemBuilder: (_, idx) {
          final item = _items[idx];
          final id = int.tryParse('${item['id']}') ?? 0;
          final active = item['is_active'] == true;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _showResponses(item),
              title: Text(
                '${item['title'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '[${item['category']}] Target: ${item['target_group']} • ${active ? 'Aktif' : 'Nonaktif'}\n'
                  'Baca: ${item['reads'] ?? 0} • Konf: ${item['confirms'] ?? 0} • Form: ${item['forms'] ?? 0}',
                  style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                      color: active ? AdminColors.gold : AdminColors.emerald,
                    ),
                    onPressed: () => _toggle(id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger),
                    onPressed: () => _delete(id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Judul Broadcast *'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Jenis Konten'),
          items: const [
            DropdownMenuItem(value: 'pengumuman', child: Text('Pengumuman Biasa')),
            DropdownMenuItem(value: 'pdf', child: Text('Dokumen PDF')),
            DropdownMenuItem(value: 'link', child: Text('Tautan / Link')),
            DropdownMenuItem(value: 'konfirmasi', child: Text('Tombol Konfirmasi')),
            DropdownMenuItem(value: 'form', child: Text('Multi-Form Dinamis (Survei)')),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'pengumuman'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _targetGroup,
          decoration: const InputDecoration(labelText: 'Target Penerima'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Semua Anggota')),
            DropdownMenuItem(value: 'puk', child: Text('Pengurus PUK')),
            DropdownMenuItem(value: 'kp', child: Text('KP')),
            DropdownMenuItem(value: 'pleno', child: Text('Pleno')),
            DropdownMenuItem(value: 'pengurus', child: Text('Semua Pengurus')),
            DropdownMenuItem(value: 'custom', child: Text('Custom Noreg')),
          ],
          onChanged: (v) => setState(() => _targetGroup = v ?? 'all'),
        ),
        if (_targetGroup == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Daftar Noreg (pisahkan koma/baris)'),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _bodyCtrl,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Isi Pengumuman / Deskripsi'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _attUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL Lampiran PDF / Link (opsional)',
            hintText: 'https://...',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _attLabelCtrl,
          decoration: const InputDecoration(labelText: 'Label Tombol File/Link (opsional)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _actionLabelCtrl,
          decoration: const InputDecoration(
            labelText: 'Label Tombol Konfirmasi (opsional)',
            hintText: 'Misal: Saya Sudah Membaca / Hadir',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Builder Multi-Form Dinamis',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _fields.add(_FormFieldDraft(
                    keyName: 'q_${_fields.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
                  ));
                });
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Tambah Field'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _fields.length; i++) _buildFieldEditor(i),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kirim Push Notifikasi FCM (target Semua)', style: TextStyle(fontSize: 13)),
          value: _sendFcm,
          onChanged: (v) => setState(() => _sendFcm = v),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.emerald),
            onPressed: _saving ? null : _sendBroadcast,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              _saving ? 'Mengirim...' : 'Kirim Broadcast Inbox',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldEditor(int idx) {
    final f = _fields[idx];
    final hasOptions = f.type == 'select' || f.type == 'radio' || f.type == 'checkbox';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: f.labelCtrl,
                    decoration: InputDecoration(
                      labelText: 'Pertanyaan #${idx + 1}',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 20),
                  onPressed: () {
                    setState(() {
                      _fields.removeAt(idx).dispose();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: f.type,
                    decoration: const InputDecoration(labelText: 'Tipe', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'text', child: Text('Teks Singkat')),
                      DropdownMenuItem(value: 'textarea', child: Text('Paragraf')),
                      DropdownMenuItem(value: 'number', child: Text('Angka')),
                      DropdownMenuItem(value: 'select', child: Text('Dropdown')),
                      DropdownMenuItem(value: 'radio', child: Text('Pilihan Tunggal')),
                      DropdownMenuItem(value: 'checkbox', child: Text('Pilihan Ganda')),
                      DropdownMenuItem(value: 'date', child: Text('Tanggal')),
                    ],
                    onChanged: (v) => setState(() => f.type = v ?? 'text'),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Checkbox(
                      value: f.required,
                      onChanged: (v) => setState(() => f.required = v ?? true),
                    ),
                    const Text('Wajib', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            if (hasOptions) ...[
              const SizedBox(height: 8),
              TextField(
                controller: f.optionsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Opsi (pisahkan koma)',
                  hintText: 'Ya, Tidak, Ragu-ragu',
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormFieldDraft {
  _FormFieldDraft({required this.keyName});
  final String keyName;
  final labelCtrl = TextEditingController();
  final optionsCtrl = TextEditingController();
  String type = 'text';
  bool required = true;

  Map<String, dynamic> toJson() => {
        'key': keyName,
        'label': labelCtrl.text.trim(),
        'type': type,
        'required': required,
        if (type == 'select' || type == 'radio' || type == 'checkbox')
          'options': optionsCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      };

  void dispose() {
    labelCtrl.dispose();
    optionsCtrl.dispose();
  }
}
