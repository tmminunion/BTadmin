import 'package:cached_network_image/cached_network_image.dart';
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

  // Subscriber WA controllers
  final _subSearchCtrl = TextEditingController();
  final _subNomorCtrl = TextEditingController();
  final _addSubNamaCtrl = TextEditingController();
  final _addSubNoregCtrl = TextEditingController();
  final _addSubNomorCtrl = TextEditingController();
  bool _addingSub = false;

  bool _loading = true;
  bool _sending = false;
  bool _uploadingImg = false;
  bool _balancing = false;
  bool _deduping = false;
  bool _loadingSubs = false;
  bool _unsubbing = false;
  String _statusFilter = '__active__';
  String _baileyFilter = '';
  Map<String, dynamic> _baileyStats = const {};
  List<Map<String, dynamic>> _items = const [];
  int _subTotal = 0;
  List<Map<String, dynamic>> _subscribers = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _load();
    _loadSubscribers();
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
    _subSearchCtrl.dispose();
    _subNomorCtrl.dispose();
    _addSubNamaCtrl.dispose();
    _addSubNoregCtrl.dispose();
    _addSubNomorCtrl.dispose();
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

  Future<void> _confirmAssignAll(int target) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pindahkan Semua ke Bailey $target'),
        content: Text(
          'Pindahkan SEMUA antrean aktif Wanotif ke Bailey $target?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  target == 1 ? AdminColors.sky : AdminColors.emerald,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('All ke Bailey $target'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _balancing = true);
    try {
      final msg = await _api.postAction(widget.token, 'wanotif_action', {
        'action': 'assign_all',
        'bailey': target,
      });
      _snack(msg);
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _balancing = false);
    }
  }

  Future<void> _confirmDedup(int dupCount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Antrean Duplikat'),
        content: Text(
          'Ditemukan $dupCount pesan duplikat aktif (nomor & isi sama).\n\n'
          'Sistem akan mempertahankan 1 pesan terawal dan menghapus duplikatnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Duplikat'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deduping = true);
    try {
      final msg = await _api.postAction(widget.token, 'wanotif_action', {
        'action': 'dedup',
      });
      _snack(msg);
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _deduping = false);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id']}') ?? 0;
    if (id <= 0) return;
    final targetCtrl = TextEditingController(
      text: '${item['target'] ?? item['target_audience'] ?? ''}',
    );
    final isiCtrl = TextEditingController(
      text: '${item['isi'] ?? item['isi_news'] ?? ''}',
    );
    int bailey = int.tryParse('${item['bailey'] ?? 1}') ?? 1;
    if (bailey != 1 && bailey != 2) bailey = 1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Edit Antrean #$id'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: targetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor / Target WA',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: bailey,
                  decoration: const InputDecoration(
                    labelText: 'Worker Bailey',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Bailey 1')),
                    DropdownMenuItem(value: 2, child: Text('Bailey 2')),
                  ],
                  onChanged: (v) => setS(() => bailey = v ?? 1),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: isiCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Isi Pesan',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AdminColors.emerald),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        final msg = await _api.postAction(widget.token, 'wanotif_action', {
          'action': 'update',
          'id': id,
          'target': targetCtrl.text.trim(),
          'isi': isiCtrl.text.trim(),
          'bailey': bailey,
        });
        _snack(msg);
        await _load();
      } catch (e) {
        _snack('$e', isError: true);
      }
    }
    targetCtrl.dispose();
    isiCtrl.dispose();
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

  Future<void> _loadSubscribers() async {
    setState(() => _loadingSubs = true);
    try {
      final q = Uri.encodeQueryComponent(_subSearchCtrl.text.trim());
      final data = await _api.getJson(
        widget.token,
        'wanotif_subscribers?q=$q',
      );
      if (!mounted) return;
      setState(() {
        _subTotal = int.tryParse('${data['total'] ?? 0}') ?? 0;
        _subscribers = (data['items'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _loadingSubs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSubs = false);
      _snack('$e', isError: true);
    }
  }

  Future<void> _confirmQuickUnsub() async {
    final raw = _subNomorCtrl.text.trim();
    if (raw.isEmpty) {
      _snack('Masukkan nomor WhatsApp terlebih dahulu.', isError: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cabut Subscribe WA?'),
        content: Text(
          'Hapus nomor berikut dari daftar subscribe_news?\n\n$raw',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Cabut'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _unsubbing = true);
    try {
      final msg = await _api.postAction(
        widget.token,
        'wanotif_unsubscribe',
        {'nomor': raw},
      );
      _subNomorCtrl.clear();
      _snack(msg);
      await _loadSubscribers();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _unsubbing = false);
    }
  }

  Future<void> _confirmUnsubById(int id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cabut Subscribe WA?'),
        content: Text(
          'Batalkan langganan berita WhatsApp untuk:\n\n$label',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await _api.postAction(
        widget.token,
        'wanotif_unsubscribe',
        {'id': id},
      );
      _snack(msg);
      await _loadSubscribers();
    } catch (e) {
      _snack('$e', isError: true);
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AdminColors.gold,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          tabs: const [
            Tab(text: 'Antrean WA'),
            Tab(text: 'Broadcast WA'),
            Tab(text: 'Push FCM'),
            Tab(text: 'Subscriber WA'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (_tab.index == 3) {
                _loadSubscribers();
              } else {
                _load();
              }
            },
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
          _buildSubscribersTab(),
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
    final dupCount = int.tryParse('${_baileyStats['dup_count'] ?? 0}') ?? 0;
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
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
                      _balancing ? 'Menyeimbangkan...' : 'Balancing Job',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              if (dupCount > 0) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.danger,
                      side: const BorderSide(color: AdminColors.danger),
                    ),
                    onPressed: (_deduping || _loading)
                        ? null
                        : () => _confirmDedup(dupCount),
                    icon: _deduping
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cleaning_services_rounded, size: 16),
                    label: Text(
                      'Dedup ($dupCount)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.sky,
                      side: const BorderSide(color: AdminColors.sky),
                    ),
                    onPressed: (_balancing || _loading)
                        ? null
                        : () => _confirmAssignAll(1),
                    icon: const Icon(Icons.looks_one_rounded, size: 16),
                    label: const Text(
                      'All ke Bailey 1',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.emerald,
                      side: const BorderSide(color: AdminColors.emerald),
                    ),
                    onPressed: (_balancing || _loading)
                        ? null
                        : () => _confirmAssignAll(2),
                    icon: const Icon(Icons.looks_two_rounded, size: 16),
                    label: const Text(
                      'All ke Bailey 2',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
                              onTap: () => _showEditDialog(item),
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
            child: CachedNetworkImage(
              imageUrl: url,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              maxHeightDiskCache: 400,
              fadeInDuration: const Duration(milliseconds: 200),
              progressIndicatorBuilder: (_, __, progress) => SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(value: progress.progress, strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
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

  Future<void> _addSubscriberByPhone() async {
    final raw = _addSubNomorCtrl.text.trim();
    if (raw.isEmpty) {
      _snack('Masukkan nomor WhatsApp yang ingin didaftarkan.', isError: true);
      return;
    }
    setState(() => _addingSub = true);
    try {
      final msg = await _api.postAction(
        widget.token,
        'wanotif_subscribe',
        {
          'nomor': raw,
          'nama': _addSubNamaCtrl.text.trim(),
          'noreg': _addSubNoregCtrl.text.trim(),
        },
      );
      _addSubNomorCtrl.clear();
      _addSubNamaCtrl.clear();
      _addSubNoregCtrl.clear();
      _snack(msg);
      await _loadSubscribers();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _addingSub = false);
    }
  }

  Widget _buildSubscribersTab() {
    return RefreshIndicator(
      onRefresh: _loadSubscribers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card Tambah Subscriber WA Baru
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AdminColors.success.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AdminColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tambah Subscriber WA',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          Text(
                            'Daftarkan 1 atau banyak nomor (pisah koma/baris)',
                            style: TextStyle(fontSize: 11.5, color: AdminColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addSubNamaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama (opsional)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _addSubNoregCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Noreg (opsional)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addSubNomorCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp *',
                    hintText: '08118127736 atau 62812...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
                    onPressed: _addingSub ? null : _addSubscriberByPhone,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: Text(_addingSub ? 'Menyimpan...' : 'Tambah Subscriber'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Card Cabut Cepat by No WA
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AdminColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.unsubscribe_rounded,
                        color: AdminColors.danger,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cabut Subscribe via No. WA',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Total aktif: $_subTotal subscriber',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subNomorCtrl,
                  maxLines: 2,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp (bisa lebih dari 1, pisah koma/enter)',
                    hintText: 'Contoh: 08118127736 atau 628118127736',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.danger,
                    ),
                    onPressed: _unsubbing ? null : _confirmQuickUnsub,
                    icon: const Icon(Icons.person_remove_rounded, size: 18),
                    label: Text(
                      _unsubbing ? 'Memproses...' : 'Cabut Subscribe Nomor Ini',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar Subscriber
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari No WA / Nama / Noreg...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    suffixIcon: _subSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _subSearchCtrl.clear();
                              _loadSubscribers();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _loadSubscribers(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadSubscribers,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                child: const Text('Cari'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loadingSubs)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_subscribers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border),
              ),
              child: const Text(
                'Tidak ada subscriber yang cocok.',
                style: TextStyle(color: AdminColors.textSecondary),
              ),
            )
          else
            ..._subscribers.map((s) {
              final id = int.tryParse('${s['id'] ?? 0}') ?? 0;
              final nama = (s['nama'] ?? '-').toString();
              final noreg = (s['noreg'] ?? '-').toString();
              final nomor = (s['nomor'] ?? '-').toString();
              final created = (s['created_at'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AdminColors.emerald
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  nomor,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.emerald,
                                  ),
                                ),
                              ),
                              if (noreg.isNotEmpty && noreg != '-')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AdminColors.sky
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    noreg,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.sky,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (created.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Terdaftar: $created',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.danger,
                        side: BorderSide(
                          color: AdminColors.danger.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: id > 0
                          ? () => _confirmUnsubById(id, '$nama ($nomor)')
                          : null,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'Cabut',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
