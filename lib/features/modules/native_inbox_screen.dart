import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _webhookCtrl = TextEditingController();

  String _category = 'pengumuman';
  String _targetGroup = 'all';
  bool _sendFcm = false;
  bool _preventScreenshot = false;
  bool _allowDelete = true;
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
    _webhookCtrl.dispose();
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

  void _loadPreset(Map<String, dynamic> item) {
    _titleCtrl.text = '${item['title'] ?? ''}';
    _bodyCtrl.text = '${item['body'] ?? ''}';
    _customCtrl.text = '${item['target_noregs'] ?? ''}';
    _attUrlCtrl.text = '${item['attachment_url'] ?? ''}';
    _attLabelCtrl.text = '${item['attachment_label'] ?? ''}';
    _actionLabelCtrl.text = '${item['action_label'] ?? ''}';
    _webhookCtrl.text = '${item['webhook_url'] ?? ''}';
    for (final f in _fields) {
      f.dispose();
    }
    _fields.clear();
    final rawSchema = item['form_schema'];
    if (rawSchema is List) {
      for (final raw in rawSchema.whereType<Map>()) {
        final f = _FormFieldDraft(
          keyName: '${raw['key'] ?? 'q_${_fields.length + 1}'}',
        );
        f.labelCtrl.text = '${raw['label'] ?? ''}';
        f.type = '${raw['type'] ?? 'text'}';
        f.required = raw['required'] != false;
        if (raw['options'] is List) {
          f.optionsCtrl.text =
              (raw['options'] as List).map((e) => e.toString()).join(', ');
        }
        _fields.add(f);
      }
    }
    setState(() {
      _category = '${item['category'] ?? 'pengumuman'}';
      _targetGroup = '${item['target_group'] ?? 'all'}';
      _preventScreenshot = item['prevent_screenshot'] == true;
      _allowDelete = item['allow_delete'] != false;
    });
    _tab.animateTo(1);
    _snack('Template/broadcast dimuat ke editor.');
  }

  Future<void> _sendBroadcast({bool isTemplate = false}) async {
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
        'webhook_url': _webhookCtrl.text.trim(),
        'is_template': isTemplate,
        'send_fcm': isTemplate ? false : _sendFcm,
        'prevent_screenshot': _preventScreenshot,
        'allow_delete': _allowDelete,
      });
      _snack(msg);
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _customCtrl.clear();
      _attUrlCtrl.clear();
      _attLabelCtrl.clear();
      _actionLabelCtrl.clear();
      _webhookCtrl.clear();
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
                    tooltip: 'Pakai Ulang',
                    icon: const Icon(Icons.copy_rounded, size: 19, color: AdminColors.sky),
                    onPressed: () => _loadPreset(item),
                  ),
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
            DropdownMenuItem(value: 'member', child: Text('Member (Non-Pengurus)')),
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
        Row(
          children: [
            const Expanded(
              child: Text(
                'Isi Pesan / HTML Template',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () {
                _bodyCtrl.text =
                    '<div style="font-family:sans-serif;color:#1e293b;">'
                    '<div style="background:linear-gradient(135deg,#0b3b8c,#0f766e);color:#fff;padding:16px;border-radius:12px;margin-bottom:12px;">'
                    '<div style="font-size:11px;font-weight:bold;">PUK SP LEM SPSI PT. TMMIN</div>'
                    '<h2 style="margin:6px 0 0;font-size:17px;color:#fff;">Informasi Resmi Pengurus</h2></div>'
                    '<p>Dear Rekan-rekan Anggota TMMIN,</p>'
                    '<p>Berikut kami sampaikan informasi terbaru:</p>'
                    '<ul><li>Poin pertama</li><li>Poin kedua</li></ul>'
                    '</div>';
              },
              child: const Text('Template Newsletter', style: TextStyle(fontSize: 11.5)),
            ),
            TextButton(
              onPressed: () {
                _bodyCtrl.text =
                    '<div style="font-family:sans-serif;color:#1e293b;">'
                    '<div style="background:#0f172a;color:#fff;padding:16px;border-radius:12px;margin-bottom:12px;">'
                    '<span style="background:#10b981;color:#fff;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:bold;">UNDANGAN RESMI</span>'
                    '<h2 style="margin:8px 0 0;font-size:17px;color:#fff;">Agenda Pertemuan / Koordinasi</h2></div>'
                    '<p>Yth. Rekan-rekan Anggota,</p>'
                    '<p><b>Hari/Tgl:</b> ...<br><b>Waktu:</b> ... WIB<br><b>Tempat:</b> ...</p>'
                    '<p>Mohon kesediaannya menekan tombol konfirmasi di bawah.</p>'
                    '</div>';
              },
              child: const Text('Template Undangan', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final txt = data?.text?.trim() ?? '';
                if (txt.isEmpty) {
                  _snack('Clipboard kosong.', isError: true);
                  return;
                }
                setState(() => _bodyCtrl.text = txt);
                _snack('Script HTML BEE / Mail Studio ditempel (${txt.length} karakter).');
              },
              icon: const Icon(Icons.content_paste_rounded, size: 15),
              label: const Text('Paste HTML BEE / Studio', style: TextStyle(fontSize: 11.5)),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                if (_bodyCtrl.text.trim().isEmpty) return;
                await Clipboard.setData(ClipboardData(text: _bodyCtrl.text));
                _snack('Script HTML disalin ke clipboard.');
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copy HTML', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bodyCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Bisa teks biasa atau HTML lengkap...',
          ),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Blokir Screenshot & Screen Record (Anti-SS)', style: TextStyle(fontSize: 13)),
          value: _preventScreenshot,
          onChanged: (v) => setState(() => _preventScreenshot = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Izinkan Anggota Hapus Pesan Ini', style: TextStyle(fontSize: 13)),
          value: _allowDelete,
          onChanged: (v) => setState(() => _allowDelete = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _webhookCtrl,
          decoration: const InputDecoration(
            labelText: 'URL API / Webhook Tujuan (opsional)',
            hintText: 'https://... (terima POST JSON konfirmasi / survey)',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AdminColors.emerald),
                  onPressed: _saving ? null : () => _sendBroadcast(isTemplate: false),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    _saving ? 'Mengirim...' : 'Kirim Broadcast',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _sendBroadcast(isTemplate: true),
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('Template'),
              ),
            ),
          ],
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
