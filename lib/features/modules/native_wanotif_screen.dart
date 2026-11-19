import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeWanotifScreen extends StatefulWidget {
  const NativeWanotifScreen({
    super.key,
    required this.token,
    required this.initialTab,
    this.onOpenWeb,
  });

  final String token;
  final int initialTab; // 0 = Antrean WA, 1 = Broadcast WA, 2 = Push FCM
  final VoidCallback? onOpenWeb;

  @override
  State<NativeWanotifScreen> createState() => _NativeWanotifScreenState();
}

class _NativeWanotifScreenState extends State<NativeWanotifScreen>
    with SingleTickerProviderStateMixin {
  final _api = BtAdminApi();
  late final TabController _tab;
  final _qCtrl = TextEditingController();

  // Broadcast WA controllers
  String _waGroup = 'puk';
  final _waMsgCtrl = TextEditingController();
  final _waCustomCtrl = TextEditingController();
  final _waImageCtrl = TextEditingController();

  // Broadcast Push FCM controllers
  String _fcmGroup = 'all_topic';
  String _fcmUrl = '/news';
  final _fcmTitleCtrl = TextEditingController(text: 'Info Pengurus Bungtemin');
  final _fcmMsgCtrl = TextEditingController();
  final _fcmCustomCtrl = TextEditingController();
  final _fcmImageCtrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  bool _uploadingImg = false;
  bool _balancing = false;
  String _statusFilter = '__active__';
  String _baileyFilter = '';
  Map<String, dynamic> _baileyStats = const {};
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _qCtrl.dispose();
    _waMsgCtrl.dispose();
    _waCustomCtrl.dispose();
    _waImageCtrl.dispose();
    _fcmTitleCtrl.dispose();
    _fcmMsgCtrl.dispose();
    _fcmCustomCtrl.dispose();
    _fcmImageCtrl.dispose();
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
      final q = Uri.encodeQueryComponent(_qCtrl.text.trim());
      final st = Uri.encodeQueryComponent(_statusFilter);
      final bl = Uri.encodeQueryComponent(_baileyFilter);
      final data = await _api.getJson(
        widget.token,
        'wanotif_queue?status=$st&bailey=$bl&q=$q',
      );
      if (!mounted) return;
      final stats = data['bailey_stats'];
      setState(() {
        _baileyStats = stats is Map<String, dynamic> ? stats : const {};
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

  Future<void> _queueAction(String action, {int? id}) async {
    try {
      final msg = await _api.postAction(widget.token, 'wanotif_action', {
        'action': action,
        if (id != null) 'id': id,
      });
      _snack(msg);
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _confirmBalance() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Balance Job Bailey 1 & 2'),
        content: const Text(
          'Seimbangkan antrean aktif antara Bailey 1 dan Bailey 2?\n\n'
          'Semua pesan untuk satu nomor tujuan akan tetap berada di Bailey yang sama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.emerald),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Balance Sekarang'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _balancing = true);
    try {
      final msg = await _api.postAction(widget.token, 'wanotif_action', {
        'action': 'balance',
      });
      _snack(msg);
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _balancing = false);
    }
  }

  String _formatDuration(int sec) {
    if (sec <= 0) return '0 menit';
    final d = sec ~/ 86400;
    final h = (sec % 86400) ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final parts = <String>[];
    if (d > 0) parts.add('$d hari');
    if (h > 0) parts.add('$h jam');
    if (m > 0 || (d == 0 && h == 0)) parts.add('$m mnt');
    return parts.join(' ');
  }

  String _formatWibEta(int etaSec) {
    if (etaSec <= 0) return 'Selesai sekarang';
    final wib = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 7))
        .add(Duration(seconds: etaSec));
    final hh = wib.hour.toString().padLeft(2, '0');
    final mm = wib.minute.toString().padLeft(2, '0');
    final dd = wib.day.toString().padLeft(2, '0');
    final mo = wib.month.toString().padLeft(2, '0');
    final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
    final sameDay = wib.day == nowWib.day &&
        wib.month == nowWib.month &&
        wib.year == nowWib.year;
    return sameDay ? '± $hh:$mm WIB' : '± $dd/$mo $hh:$mm WIB';
  }

  Future<void> _pickAndUploadImage(TextEditingController targetCtrl) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1400,
      );
      if (picked == null) return;
      setState(() => _uploadingImg = true);
      final bytes = await picked.readAsBytes();
      final url = await _api.uploadBroadcastImage(
        widget.token,
        bytes,
        picked.name,
      );
      if (!mounted) return;
      setState(() {
        targetCtrl.text = url;
        _uploadingImg = false;
      });
      _snack('Gambar berhasil diupload!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImg = false);
      _snack('$e', isError: true);
    }
  }

  Future<void> _sendWaBroadcast() async {
    final msg = _waMsgCtrl.text.trim();
    if (msg.isEmpty) {
      _snack('Isi pesan WhatsApp wajib diisi.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await _api.postAction(widget.token, 'wanotif_broadcast', {
        'target_group': _waGroup,
        'message': msg,
        'send_wa': true,
        'send_fcm': false,
        'custom_targets': _waCustomCtrl.text.trim(),
        'image_url': _waImageCtrl.text.trim(),
      });
      _snack(res);
      _waMsgCtrl.clear();
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendFcmBroadcast() async {
    final msg = _fcmMsgCtrl.text.trim();
    final title = _fcmTitleCtrl.text.trim();
    if (msg.isEmpty || title.isEmpty) {
      _snack('Judul & isi notifikasi FCM wajib diisi.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await _api.postAction(widget.token, 'wanotif_broadcast', {
        'target_group': _fcmGroup,
        'title': title,
        'message': msg,
        'fcm_url': _fcmUrl,
        'send_wa': false,
        'send_fcm': true,
        'custom_targets': _fcmCustomCtrl.text.trim(),
        'image_url': _fcmImageCtrl.text.trim(),
      });
      _snack(res);
      _fcmMsgCtrl.clear();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Wanotif & Push FCM'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AdminColors.gold,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          tabs: const [
            Tab(text: 'Antrean WA'),
            Tab(text: 'Broadcast WA'),
            Tab(text: 'Push FCM'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildQueueTab(),
          _buildWaBroadcastTab(),
          _buildFcmBroadcastTab(),
        ],
      ),
    );
  }

  Widget _buildBaileyOverviewCard() {
    final b1 = int.tryParse('${_baileyStats['b1'] ?? 0}') ?? 0;
    final b2 = int.tryParse('${_baileyStats['b2'] ?? 0}') ?? 0;
    final lain = int.tryParse('${_baileyStats['lain'] ?? 0}') ?? 0;
    final numbers = int.tryParse('${_baileyStats['numbers'] ?? 0}') ?? 0;
    final mixed = int.tryParse('${_baileyStats['mixed'] ?? 0}') ?? 0;
    final activeTotal =
        int.tryParse('${_baileyStats['active_total'] ?? (b1 + b2 + lain)}') ??
            (b1 + b2 + lain);
    final etaSec = int.tryParse('${_baileyStats['eta_sec'] ?? 0}') ?? 0;
    final pauseAll = _baileyStats['pause_all'] == true;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.balance_rounded,
                size: 18,
                color: AdminColors.sky,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Beban Bailey & Estimasi',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (pauseAll)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PAUSED',
                    style: TextStyle(
                      color: AdminColors.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _baileyCountBox('Bailey 1', b1, AdminColors.sky),
              const SizedBox(width: 8),
              _baileyCountBox('Bailey 2', b2, AdminColors.emerald),
              if (lain > 0) ...[
                const SizedBox(width: 8),
                _baileyCountBox('Lainnya', lain, AdminColors.gold),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AdminColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activeTotal == 0
                      ? 'Tidak ada antrean aktif'
                      : 'Estimasi: ${_formatDuration(etaSec)} (${_formatWibEta(etaSec)})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$activeTotal pesan aktif • $numbers nomor tujuan (~23 mnt/pesan per Bailey)'
            '${mixed > 0 ? ' • $mixed nomor terpecah!' : ''}',
            style: TextStyle(
              fontSize: 11.5,
              color: mixed > 0 ? AdminColors.danger : AdminColors.textSecondary,
              fontWeight: mixed > 0 ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: (_balancing || _loading) ? null : _confirmBalance,
              icon: _balancing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shuffle_rounded, size: 17),
              label: Text(
                _balancing ? 'Menyeimbangkan...' : 'Balancing Job Bailey 1 & 2',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _baileyCountBox(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count antrean',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    return Column(
      children: [
        _buildBaileyOverviewCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari nomor WA / isi pesan...',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: _load,
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (act) => _queueAction(act),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'retry_errors',
                    child: Text('Follow-Up Semua Error'),
                  ),
                  PopupMenuItem(
                    value: 'purge_done',
                    child: Text('Bersihkan Riwayat Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (val, lbl) in [
                ('__active__', 'Aktif'),
                ('', 'Semua'),
                ('error', 'Error'),
                ('done', 'Done'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(lbl),
                    selected: _statusFilter == val,
                    onSelected: (_) {
                      setState(() => _statusFilter = val);
                      _load();
                    },
                  ),
                ),
              const SizedBox(width: 6),
              for (final (bVal, bLbl) in [
                ('', 'Semua Bailey'),
                ('1', 'Bailey 1'),
                ('2', 'Bailey 2'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(bLbl),
                    selected: _baileyFilter == bVal,
                    onSelected: (_) {
                      setState(() => _baileyFilter = bVal);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Antrean kosong.',
                        style: TextStyle(color: AdminColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                        itemCount: _items.length,
                        itemBuilder: (_, idx) {
                          final item = _items[idx];
                          final id = int.tryParse('${item['id']}') ?? 0;
                          final target =
                              '${item['target'] ?? item['target_audience'] ?? ''}';
                          final st = '${item['status'] ?? ''}';
                          final bailey =
                              int.tryParse('${item['bailey'] ?? 1}') ?? 1;
                          final msg =
                              '${item['isi'] ?? item['isi_news'] ?? ''}';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                '#$id • $target [$st] • B$bailey',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: Text(
                                msg,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      size: 19,
                                      color: AdminColors.emerald,
                                    ),
                                    tooltip: 'Follow Up (UTAMA)',
                                    onPressed: () =>
                                        _queueAction('retry', id: id),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 19,
                                      color: AdminColors.danger,
                                    ),
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
    );
  }

  Widget _imagePickerSection(TextEditingController ctrl) {
    final url = ctrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'URL Gambar (opsional)',
                  hintText: 'https://bungtemin.net/...',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _uploadingImg ? null : () => _pickAndUploadImage(ctrl),
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.sky,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              icon: _uploadingImg
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_rounded, size: 18),
              label: const Text('Upload'),
            ),
          ],
        ),
        if (url.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWaBroadcastTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _waGroup,
          decoration: const InputDecoration(labelText: 'Target Grup WhatsApp'),
          items: const [
            DropdownMenuItem(value: 'puk', child: Text('Pengurus PUK')),
            DropdownMenuItem(value: 'kp', child: Text('KP (Koordinator Plant)')),
            DropdownMenuItem(value: 'pleno', child: Text('Pleno')),
            DropdownMenuItem(
              value: 'pengurus',
              child: Text('Semua Pengurus (PUK + KP + Pleno)'),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Text('Custom (Noreg / Nomor WA Manual)'),
            ),
          ],
          onChanged: (v) => setState(() => _waGroup = v ?? 'puk'),
        ),
        if (_waGroup == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _waCustomCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Noreg / Nomor WA (pisahkan koma/baris baru)',
            ),
          ),
        ],
        const SizedBox(height: 12),
        _imagePickerSection(_waImageCtrl),
        const SizedBox(height: 12),
        TextField(
          controller: _waMsgCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Pesan / Caption WhatsApp',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.emerald),
            onPressed: _sending ? null : _sendWaBroadcast,
            icon: const Icon(Icons.chat_rounded),
            label: Text(
              _sending ? 'Mengantrekan...' : 'Antrekan Broadcast WhatsApp',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFcmBroadcastTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _fcmGroup,
          decoration: const InputDecoration(labelText: 'Target Push Notifikasi'),
          items: const [
            DropdownMenuItem(
              value: 'all_topic',
              child: Text('Semua Pengguna App (Topic: news)'),
            ),
            DropdownMenuItem(value: 'puk', child: Text('Pengurus PUK')),
            DropdownMenuItem(value: 'kp', child: Text('KP (Koordinator Plant)')),
            DropdownMenuItem(value: 'pleno', child: Text('Pleno')),
            DropdownMenuItem(
              value: 'pengurus',
              child: Text('Semua Pengurus (PUK + KP + Pleno)'),
            ),
            DropdownMenuItem(value: 'custom', child: Text('Custom (Noreg Manual)')),
          ],
          onChanged: (v) => setState(() => _fcmGroup = v ?? 'all_topic'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fcmTitleCtrl,
          decoration: const InputDecoration(labelText: 'Judul Notifikasi'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _fcmUrl,
          decoration: const InputDecoration(labelText: 'Rute Tujuan Saat Tap'),
          items: const [
            DropdownMenuItem(value: '/news', child: Text('/news (Berita)')),
            DropdownMenuItem(value: '/meeting', child: Text('/meeting (Meeting)')),
            DropdownMenuItem(value: '/chat', child: Text('/chat (Chat)')),
            DropdownMenuItem(value: '/kalender', child: Text('/kalender (Kalender)')),
            DropdownMenuItem(value: '/home', child: Text('/home (Beranda)')),
          ],
          onChanged: (v) => setState(() => _fcmUrl = v ?? '/news'),
        ),
        if (_fcmGroup == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _fcmCustomCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Daftar Noreg Target (pisahkan koma/baris baru)',
            ),
          ),
        ],
        const SizedBox(height: 12),
        _imagePickerSection(_fcmImageCtrl),
        const SizedBox(height: 12),
        TextField(
          controller: _fcmMsgCtrl,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Isi Notifikasi Push'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.sky),
            onPressed: _sending ? null : _sendFcmBroadcast,
            icon: const Icon(Icons.notifications_active_rounded),
            label: Text(
              _sending ? 'Mengirim...' : 'Kirim Push Notifikasi FCM',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
