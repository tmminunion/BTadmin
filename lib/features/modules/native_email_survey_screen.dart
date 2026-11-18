import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeEmailScreen extends StatefulWidget {
  const NativeEmailScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeEmailScreen> createState() => _NativeEmailScreenState();
}

class _NativeEmailScreenState extends State<NativeEmailScreen> {
  final _api = BtAdminApi();
  final _toCtrl = TextEditingController();
  final _subjCtrl = TextEditingController(text: 'Test Email dari BTadmin');
  final _bodyCtrl = TextEditingController(
    text: 'Halo! Ini adalah email uji coba dari aplikasi BTadmin.',
  );
  bool _sending = false;

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final msg = await _api.postAction(widget.token, 'email_send', {
        'recipient': _toCtrl.text.trim(),
        'subject': _subjCtrl.text.trim(),
        'message': _bodyCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AdminColors.emerald),
      );
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
        title: const Text('Kirim & Uji Email SMTP'),
        actions: [
          TextButton(
            onPressed: widget.onOpenWeb,
            child: const Text('Web', style: TextStyle(color: AdminColors.gold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _toCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Penerima',
                      hintText: 'contoh@tmmin.co.id',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subjCtrl,
                    decoration: const InputDecoration(labelText: 'Subjek'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Isi Pesan'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.mark_email_read_rounded),
                    label: Text(_sending ? 'Mengirim...' : 'Kirim Email'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NativeSurveyScreen extends StatefulWidget {
  const NativeSurveyScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeSurveyScreen> createState() => _NativeSurveyScreenState();
}

class _NativeSurveyScreenState extends State<NativeSurveyScreen> {
  final _api = BtAdminApi();
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJson(widget.token, 'surveys');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survei & Polling'),
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
          : _items.isEmpty
              ? const Center(child: Text('Belum ada survei.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, idx) {
                      final sv = _items[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.poll_rounded,
                              color: AdminColors.gold),
                          title: Text(
                            (sv['title'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Status: ${sv['status']} • ${sv['responses']} responden',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new_rounded),
                            onPressed: widget.onOpenWeb,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
