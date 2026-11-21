import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeWebhookScreen extends StatefulWidget {
  const NativeWebhookScreen({super.key, required this.token});

  final String token;

  @override
  State<NativeWebhookScreen> createState() => _NativeWebhookScreenState();
}

class _NativeWebhookScreenState extends State<NativeWebhookScreen>
    with SingleTickerProviderStateMixin {
  final _api = BtAdminApi();
  late final TabController _tab;

  bool _loading = true;
  bool _saving = false;
  bool _nudbOnline = false;
  String _hookBase = 'https://nudb.bungtemin.net/api/webhook/hook/';
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _hooks = const [];
  List<Map<String, dynamic>> _logs = const [];

  // Form controllers
  int _editId = 0;
  final _nameCtrl = TextEditingController();
  String _direction = 'outgoing';
  String _actionType = 'mysql_table';
  String _eventName = 'inbox.form';
  String _method = 'POST';
  final _slugCtrl = TextEditingController();
  final _tableCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _isActive = true;

  static const _events = <String>[
    'inbox.form',
    'inbox.confirm',
    'lapor.created',
    'kta.updated',
    'wanotif.broadcast',
    '*',
  ];

  static const _actionLabels = <String, String>{
    'mysql_table': 'MySQL Prisma Auto-Table',
    'nudb_json': 'NUDB JSON Store',
    'http': 'HTTP Forward',
    'mysql_and_http': 'MySQL + HTTP',
    'workflow': 'Visual Workflow (n8n)',
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _tableCtrl.dispose();
    _urlCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AdminColors.danger : AdminColors.success,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getJson(widget.token, 'webhooks_list');
      if (!mounted) return;
      setState(() {
        _nudbOnline = res['nudb_online'] == true;
        _hookBase = (res['hook_base'] ?? _hookBase).toString();
        _stats = (res['stats'] is Map)
            ? Map<String, dynamic>.from(res['stats'] as Map)
            : const {};
        _hooks = (res['hooks'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [];
        _logs = (res['logs'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _resetForm() {
    setState(() {
      _editId = 0;
      _nameCtrl.clear();
      _direction = 'outgoing';
      _actionType = 'mysql_table';
      _eventName = 'inbox.form';
      _method = 'POST';
      _slugCtrl.clear();
      _tableCtrl.clear();
      _urlCtrl.clear();
      _secretCtrl.clear();
      _isActive = true;
    });
  }

  void _loadToForm(Map<String, dynamic> h) {
    setState(() {
      _editId = int.tryParse('${h['id'] ?? 0}') ?? 0;
      _nameCtrl.text = (h['name'] ?? '').toString();
      _direction = (h['direction'] ?? 'outgoing').toString();
      _actionType = (h['action_type'] ?? 'http').toString();
      final ev = (h['event_name'] ?? 'inbox.form').toString();
      _eventName = _events.contains(ev) ? ev : 'inbox.form';
      _method = (h['method'] ?? 'POST').toString();
      _slugCtrl.text = (h['slug'] ?? '').toString();
      _tableCtrl.text = (h['table_name'] ?? '').toString();
      _urlCtrl.text = (h['target_url'] ?? '').toString();
      _secretCtrl.text = (h['secret'] ?? '').toString();
      _isActive = (h['is_active'] == 1 || h['is_active'] == true);
    });
    _tab.animateTo(1);
  }

  Future<void> _saveWebhook() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Nama webhook wajib diisi.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final msg = await _api.postAction(widget.token, 'webhook_save', {
        'id': _editId,
        'name': _nameCtrl.text.trim(),
        'direction': _direction,
        'action_type': _actionType,
        'event_name': _eventName,
        'slug': _slugCtrl.text.trim(),
        'table_name': _tableCtrl.text.trim(),
        'target_url': _urlCtrl.text.trim(),
        'method': _method,
        'secret': _secretCtrl.text.trim(),
        'is_active': _isActive ? 1 : 0,
      });
      _snack(msg);
      _resetForm();
      await _load();
      _tab.animateTo(0);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testWebhook(int id) async {
    try {
      final msg = await _api.postAction(widget.token, 'webhook_test', {'id': id});
      _snack(msg);
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _toggleWebhook(int id) async {
    try {
      final msg = await _api.postAction(widget.token, 'webhook_toggle', {'id': id});
      _snack(msg);
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _deleteWebhook(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Webhook?'),
        content: Text('Hapus webhook "$name" (#$id)?'),
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
      final msg = await _api.postAction(widget.token, 'webhook_delete', {'id': id});
      _snack(msg);
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _retryLog(int logId) async {
    try {
      final msg = await _api.postAction(widget.token, 'webhook_retry_log', {'log_id': logId});
      _snack(msg);
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openTableViewer(int id, String name) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.94,
        builder: (_, scrollCtrl) => FutureBuilder<Map<String, dynamic>>(
          future: _api.getJson(widget.token, 'webhook_table_data?id=$id'),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return Center(child: Text('Gagal memuat tabel: ${snap.error}'));
            }
            final data = snap.data!;
            final cols = (data['columns'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
            final rows = (data['rows'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
            final tblName = (data['name'] ?? '-').toString();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tabel: $name',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              '$tblName · ${rows.length} baris',
                              style: const TextStyle(fontSize: 12, color: AdminColors.muted),
                            ),
                          ],
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
                  child: rows.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Belum ada data tersimpan di tabel ini.'),
                          ),
                        )
                      : SingleChildScrollView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AdminColors.surface),
                              columns: cols
                                  .map((c) => DataColumn(
                                        label: Text(
                                          c,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              rows: rows
                                  .map((r) => DataRow(
                                        cells: cols
                                            .map((c) => DataCell(
                                                  ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 220),
                                                    child: Text(
                                                      '${r[c] ?? ''}',
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _inspectLog(Map<String, dynamic> lg) {
    String pretty(dynamic raw) {
      final s = (raw ?? '').toString();
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(s));
      } catch (_) {
        return s.isEmpty ? '-' : s;
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log: ${lg['event_name']} (HTTP ${lg['http_status']} · ${lg['provider']})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 10),
              const Text('Request Payload', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  pretty(lg['request_payload']),
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Response / Output', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  pretty(lg['response_body']),
                  style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: AdminColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Webhook & Auto-Table',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _nudbOnline ? AdminColors.success : AdminColors.warning,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _nudbOnline ? 'NUDB Online' : 'Fallback PHP',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AdminColors.accent,
          tabs: [
            Tab(text: 'Webhook (${_hooks.length})'),
            const Tab(text: 'Tambah / Edit'),
            Tab(text: 'Logs (${_logs.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _buildListTab(),
                _buildFormTab(),
                _buildLogsTab(),
              ],
            ),
    );
  }

  Widget _buildListTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              _miniStat('Total', '${_stats['total'] ?? _hooks.length}', AdminColors.primary),
              const SizedBox(width: 8),
              _miniStat('Aktif', '${_stats['active'] ?? 0}', AdminColors.success),
              const SizedBox(width: 8),
              _miniStat('Sukses 24j', '${_stats['ok_24h'] ?? 0}', const Color(0xFF0891B2)),
              const SizedBox(width: 8),
              _miniStat('Gagal 24j', '${_stats['fail_24h'] ?? 0}', AdminColors.danger),
            ],
          ),
          const SizedBox(height: 12),
          if (_hooks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada webhook. Buka tab Tambah / Edit untuk membuat webhook MySQL Auto-Table (bunp2332_prisma) atau Incoming Hook.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._hooks.map((h) {
              final id = int.tryParse('${h['id'] ?? 0}') ?? 0;
              final name = (h['name'] ?? '-').toString();
              final dir = (h['direction'] ?? 'outgoing').toString();
              final act = (h['action_type'] ?? 'http').toString();
              final active = h['is_active'] == 1 || h['is_active'] == true;
              final hasTable = act == 'mysql_table' || act == 'nudb_json' || act == 'mysql_and_http';
              final tbl = (h['table_name'] ?? '').toString();
              final slug = (h['slug'] ?? '').toString();
              final incUrl = dir == 'incoming' ? '$_hookBase$slug' : '';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: active ? AdminColors.success.withValues(alpha: 0.14) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              active ? 'AKTIF' : 'OFF',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: active ? AdminColors.success : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(dir.toUpperCase(), style: const TextStyle(fontSize: 10.5)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          Chip(
                            label: Text(_actionLabels[act] ?? act, style: const TextStyle(fontSize: 10.5)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          if (dir == 'outgoing')
                            Chip(
                              label: Text('${h['event_name']}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      if (hasTable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            act == 'nudb_json' ? 'NUDB /store/$tbl' : 'bunp2332_prisma.wh_tbl_$tbl',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AdminColors.success, fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (incUrl.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: incUrl));
                            _snack('URL Incoming disalin!');
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Copy Incoming: $incUrl',
                              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AdminColors.primary),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (hasTable)
                            OutlinedButton.icon(
                              onPressed: () => _openTableViewer(id, name),
                              icon: const Icon(Icons.table_chart_rounded, size: 15),
                              label: const Text('Lihat Tabel', style: TextStyle(fontSize: 11.5)),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _testWebhook(id),
                            icon: const Icon(Icons.bolt_rounded, size: 15, color: AdminColors.success),
                            label: const Text('Test', style: TextStyle(fontSize: 11.5)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _loadToForm(h),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: const Text('Edit', style: TextStyle(fontSize: 11.5)),
                          ),
                          IconButton(
                            onPressed: () => _toggleWebhook(id),
                            icon: Icon(Icons.power_settings_new_rounded, color: active ? AdminColors.warning : AdminColors.success),
                            tooltip: 'Toggle Aktif',
                          ),
                          IconButton(
                            onPressed: () => _deleteWebhook(id, name),
                            icon: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger),
                            tooltip: 'Hapus',
                          ),
                        ],
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

  Widget _buildFormTab() {
    final needsTable = _actionType == 'mysql_table' || _actionType == 'nudb_json' || _actionType == 'mysql_and_http';
    final needsHttp = _actionType == 'http' || _actionType == 'mysql_and_http';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _editId > 0 ? 'Edit Webhook #$_editId' : 'Tambah Webhook Baru',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            TextButton(onPressed: _resetForm, child: const Text('Reset')),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Nama Webhook *', hintText: 'Misal: Survei Seragam 2026'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _direction,
          decoration: const InputDecoration(labelText: 'Arah Webhook'),
          items: const [
            DropdownMenuItem(value: 'outgoing', child: Text('Outgoing (Event Bungtemin)')),
            DropdownMenuItem(value: 'incoming', child: Text('Incoming (Luar -> NUDB Hook)')),
          ],
          onChanged: (v) => setState(() => _direction = v ?? 'outgoing'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _actionType,
          decoration: const InputDecoration(labelText: 'Aksi / Tujuan Data'),
          items: const [
            DropdownMenuItem(value: 'mysql_table', child: Text('Simpan MySQL Auto-Table (bunp2332_prisma)')),
            DropdownMenuItem(value: 'nudb_json', child: Text('Simpan ke NUDB JSON Store')),
            DropdownMenuItem(value: 'http', child: Text('Kirim HTTP ke URL Eksternal')),
            DropdownMenuItem(value: 'mysql_and_http', child: Text('MySQL Auto-Table + Kirim HTTP')),
          ],
          onChanged: (v) => setState(() => _actionType = v ?? 'mysql_table'),
        ),
        const SizedBox(height: 10),
        if (_direction == 'outgoing')
          DropdownButtonFormField<String>(
            value: _eventName,
            decoration: const InputDecoration(labelText: 'Event Pemicu'),
            items: _events.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _eventName = v ?? 'inbox.form'),
          )
        else
          TextField(
            controller: _slugCtrl,
            decoration: InputDecoration(
              labelText: 'Slug Incoming Hook',
              prefixText: 'hook/',
              helperText: 'URL penuh: $_hookBase<slug>',
            ),
          ),
        if (needsTable) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _tableCtrl,
            decoration: InputDecoration(
              labelText: _actionType == 'nudb_json' ? 'Nama Koleksi NUDB' : 'Nama Tabel MySQL (bunp2332_prisma)',
              prefixText: _actionType == 'nudb_json' ? 'store/' : 'wh_tbl_',
              hintText: 'survei_2026',
            ),
          ),
        ],
        if (needsHttp) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(labelText: 'Target URL Eksternal *', hintText: 'https://...'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _secretCtrl,
            decoration: const InputDecoration(labelText: 'Secret HMAC-SHA256 (opsional)'),
          ),
        ],
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aktifkan webhook segera', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _saveWebhook,
          icon: const Icon(Icons.save_rounded),
          label: Text(_saving ? 'Menyimpan...' : 'Simpan Webhook'),
        ),
      ],
    );
  }

  Widget _buildLogsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _logs.isEmpty
          ? const Center(child: Text('Belum ada Delivery Log.'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _logs.length,
              itemBuilder: (_, i) {
                final lg = _logs[i];
                final ok = lg['success'] == 1 || lg['success'] == true;
                final logId = int.tryParse('${lg['id'] ?? 0}') ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _inspectLog(lg),
                    leading: CircleAvatar(
                      backgroundColor: (ok ? AdminColors.success : AdminColors.danger).withValues(alpha: 0.15),
                      child: Icon(
                        ok ? Icons.check_rounded : Icons.error_outline_rounded,
                        color: ok ? AdminColors.success : AdminColors.danger,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      '${lg['event_name']} · HTTP ${lg['http_status']}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${lg['provider']} · ${lg['duration_ms']} ms · ${lg['created_at']}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: lg['direction'] == 'outgoing'
                        ? IconButton(
                            onPressed: () => _retryLog(logId),
                            icon: const Icon(Icons.refresh_rounded, size: 19),
                            tooltip: 'Retry',
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _miniStat(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AdminColors.muted)),
          ],
        ),
      ),
    );
  }
}
