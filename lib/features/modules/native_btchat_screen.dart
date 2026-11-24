import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeBtChatScreen extends StatefulWidget {
  const NativeBtChatScreen({super.key, required this.token});

  final String token;

  @override
  State<NativeBtChatScreen> createState() => _NativeBtChatScreenState();
}

class _BtChatMsg {
  const _BtChatMsg({
    required this.isUser,
    required this.text,
    required this.time,
    this.isError = false,
  });

  final bool isUser;
  final String text;
  final String time;
  final bool isError;
}

class _NativeBtChatScreenState extends State<NativeBtChatScreen>
    with WidgetsBindingObserver {
  final _api = BtAdminApi();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_BtChatMsg> _messages = [];
  String _conversationId = '';
  bool _sending = false;
  bool _checkingStatus = true;
  bool _authorized = false;
  String _statusLabel = 'Mengecek...';

  static const _quickPrompts = [
    'Halo, kamu siapa dan bisa bantu apa?',
    'Apa saja fitur utama aplikasi Bungtemin?',
    'Buatkan ringkasan panduan untuk anggota.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (_scrollCtrl.offset < 120) {
        _scrollToBottom();
      }
    });
  }

  String _nowLabel() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _checkStatus() async {
    setState(() {
      _checkingStatus = true;
      _statusLabel = 'Mengecek...';
    });
    try {
      final res = await _api.getJson(widget.token, 'copilot_status');
      if (!mounted) return;
      final auth = res['authorized'] == true;
      setState(() {
        _authorized = auth;
        _statusLabel = auth ? 'Terhubung' : 'Perlu OAuth';
        _checkingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authorized = false;
        _statusLabel = 'Offline';
        _checkingStatus = false;
      });
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _msgCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    if (preset == null) {
      _msgCtrl.clear();
    }

    setState(() {
      _sending = true;
      _messages.add(_BtChatMsg(isUser: true, text: text, time: _nowLabel()));
    });
    _scrollToBottom();

    try {
      final res = await _api.postJson(widget.token, 'copilot_chat', {
        'message': text,
        'conversation_id': _conversationId,
      });
      if (!mounted) return;

      final nextConv = '${res['conversation_id'] ?? ''}'.trim();
      if (nextConv.isNotEmpty) {
        _conversationId = nextConv;
      }
      final reply = '${res['reply'] ?? ''}'.trim();
      setState(() {
        _messages.add(
          _BtChatMsg(
            isUser: false,
            text: reply.isNotEmpty ? reply : '(Bot tidak mengembalikan teks balasan)',
            time: _nowLabel(),
          ),
        );
        _sending = false;
      });
    } on BtAdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _BtChatMsg(
            isUser: false,
            text: 'Gagal: ${e.message}',
            time: _nowLabel(),
            isError: true,
          ),
        );
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _BtChatMsg(
            isUser: false,
            text: 'Terjadi kesalahan: $e',
            time: _nowLabel(),
            isError: true,
          ),
        );
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  void _newChat() {
    if (_sending) return;
    setState(() {
      _conversationId = '';
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _checkingStatus
        ? Colors.grey
        : (_authorized ? Colors.green : Colors.orange);

    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BTchat · Assist Pintar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _conversationId.isEmpty
                      ? _statusLabel
                      : '$_statusLabel · ${_conversationId.substring(0, _conversationId.length > 8 ? 8 : _conversationId.length)}…',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cek Status',
            onPressed: _checkingStatus ? null : _checkStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Obrolan Baru',
            onPressed: _sending ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_checkingStatus && !_authorized)
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                'Token Copilot belum terhubung/expired. Buka Web AdminPanel → Development → Hubungkan Copilot API.',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AdminColors.primary.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              size: 30,
                              color: AdminColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Assist Pintar Bungtemin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tanyakan apa saja langsung ke Copilot Studio via API.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.topCenter,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      shrinkWrap: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, idx) {
                        final typingOffset = _sending ? 1 : 0;
                        if (typingOffset == 1 && idx == 0) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Assist Pintar sedang mengetik...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final m = _messages[_messages.length - 1 - (idx - typingOffset)];
                      return Align(
                        alignment: m.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
                            decoration: BoxDecoration(
                              color: m.isUser
                                  ? AdminColors.primary
                                  : (m.isError
                                      ? Colors.red.shade50
                                      : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: Radius.circular(m.isUser ? 14 : 4),
                                bottomRight: Radius.circular(m.isUser ? 4 : 14),
                              ),
                              border: m.isUser
                                  ? null
                                  : Border.all(
                                      color: m.isError
                                          ? Colors.red.shade200
                                          : Colors.grey.shade200,
                                    ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  m.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: m.isUser
                                        ? Colors.white
                                        : (m.isError
                                            ? Colors.red.shade900
                                            : Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      m.time,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: m.isUser
                                            ? Colors.white70
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                    if (!m.isUser) ...[
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: m.text),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Teks disalin'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'Salin',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AdminColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickPrompts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ActionChip(
                        label: Text(
                          _quickPrompts[i],
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onPressed: _sending
                            ? null
                            : () => _sendMessage(_quickPrompts[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Tulis pesan untuk Assist Pintar...',
                            filled: true,
                            fillColor: AdminColors.bg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sending ? null : () => _sendMessage(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
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
