import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeWanotifScreen extends StatefulWidget {
  const NativeWanotifScreen({
    super.key,
    required this.token,
    required this.initialTab,
    required this.onOpenWeb,
  });

  final String token;
  final int initialTab; // 0 = Antrean, 1 = Broadcast
  final VoidCallback onOpenWeb;

  @override
  State<NativeWanotifScreen> createState() => _NativeWanotifScreenState();
}

class _NativeWanotifScreenState extends State<NativeWanotifScreen>
    with SingleTickerProviderStateMixin {
  final _api = BtAdminApi();
  late final TabController _tab;
  final _qCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(text: 'Info Pengurus Bungtemin');
  final _msgCtrl = TextEditingController();
  final _targetsCtrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  String _statusFilter = '__active__';
  bool _sendFcm = true;
  bool _sendWa = false;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _qCtrl.dispose();
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _targetsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = Uri.encodeQueryComponent(_qCtrl.text.trim());
      final st = Uri.encodeQueryComponent(_statusFilter);
      final data =
          await _api.getJson(widget.token, 'wanotif_queue?status=$st&q=$q');
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

  Future<void> _queueAction(String action, {int? id}) async {
    try {
      final msg = await _api.postAction(widget.token, 'wanotif_action', {
        'action': action,
        if (id != null) 'id': id,
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

  Future<void> _sendBroadcast() async {
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi pesan wajib diisi.'),
          backgroundColor: AdminColors.danger,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final msg = await _api.postAction(widget.token, 'wanotif_broadcast', {
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'send_fcm': _sendFcm,
        'send_wa': _sendWa,
        'custom_targets': _targetsCtrl.text.trim(),
      });
      if (!mounted) return;
      _msgCtrl.clear();
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WA & Broadcast Center'),
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
          tabs: const [
            Tab(text: 'Antrean WA'),
            Tab(text: 'Kirim Broadcast'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qCtrl,
                        onSubmitted: (_) => _load(),
                        decoration: const InputDecoration(
                          hintText: 'Cari nomor tujuan atau pesan...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.flash_on_rounded,
                          color: AdminColors.gold),
                      onSelected: (v) => _queueAction(v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'retry_errors',
                          child: Text('Retry Semua Error'),
                        ),
                        PopupMenuItem(
                          value: 'purge_done',
                          child: Text('Bersihkan Yang Terkirim'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final pair in const [
                      ('__active__', 'Aktif'),
                      ('', 'Semua'),
                      ('error', 'Error'),
                      ('done', 'Terkirim'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(pair.$2),
                          selected: _statusFilter == pair.$1,
                          onSelected: (_) {
                            setState(() => _statusFilter = pair.$1);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (_, idx) {
                            final it = _items[idx];
                            final id = int.tryParse('${it['id']}') ?? 0;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  '#${it['id']} • ${it['target']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '[${it['status']} | Bailey ${it['bailey']}] ${it['isi']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AdminColors.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Retry',
                                      icon: const Icon(Icons.replay_rounded,
                                          color: AdminColors.sky),
                                      onPressed: () =>
                                          _queueAction('retry', id: id),
                                    ),
                                    IconButton(
                                      tooltip: 'Hapus',
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AdminColors.danger),
                                      onPressed: () =>
                                          _queueAction('delete', id: id),
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
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Judul Notifikasi'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _msgCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Isi Pesan Broadcast',
                          hintText: 'Tulis pengumuman untuk anggota...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Kirim Push Notifikasi HP (FCM)'),
                        value: _sendFcm,
                        activeTrackColor: AdminColors.emerald,
                        onChanged: (v) => setState(() => _sendFcm = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Kirim Pesan WhatsApp (Target Nomor)'),
                        value: _sendWa,
                        activeTrackColor: AdminColors.gold,
                        onChanged: (v) => setState(() => _sendWa = v),
                      ),
                      if (_sendWa) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _targetsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Nomor WA Tujuan (pisahkan koma / spasi)',
                            hintText: '0812xxx, 0856xxx',
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _sending ? null : _sendBroadcast,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.emerald,
                          foregroundColor: AdminColors.bg,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: Text(
                          _sending ? 'Mengirim...' : 'Kirim Broadcast Sekarang',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
