import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/admin_theme.dart';
import '../../models/admin_models.dart';
import '../../services/bt_admin_api.dart';

class AdminWebViewScreen extends StatefulWidget {
  const AdminWebViewScreen({
    super.key,
    required this.token,
    required this.module,
    required this.allModules,
  });

  final String token;
  final AdminModuleItem module;
  final List<AdminModuleItem> allModules;

  @override
  State<AdminWebViewScreen> createState() => _AdminWebViewScreenState();
}

class _AdminWebViewScreenState extends State<AdminWebViewScreen> {
  final _api = BtAdminApi();
  late final WebViewController _controller;

  late AdminModuleItem _currentModule;
  bool _loadingTicket = true;
  int _progress = 0;
  String? _error;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentModule = widget.module;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AdminColors.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _currentUrl = url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _currentUrl = url);
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == true && mounted) {
              setState(() => _error = 'Gagal memuat halaman (${err.description}).');
            }
          },
        ),
      );
    _openModule(_currentModule);
  }

  Future<void> _openModule(AdminModuleItem mod) async {
    setState(() {
      _currentModule = mod;
      _loadingTicket = true;
      _error = null;
      _progress = 10;
    });
    try {
      final ticket = await _api.requestWebTicket(
        token: widget.token,
        path: mod.path,
      );
      if (!mounted) return;
      await _controller.loadRequest(Uri.parse(ticket.url));
      if (mounted) setState(() => _loadingTicket = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTicket = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openExternal() async {
    try {
      final ticket = await _api.requestWebTicket(
        token: widget.token,
        path: _currentModule.path,
      );
      final uri = Uri.parse(ticket.url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka browser: $e')),
      );
    }
  }

  void _showQuickSwitch() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AdminColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AdminColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Pindah Modul Admin Panel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: widget.allModules.length,
                itemBuilder: (_, idx) {
                  final m = widget.allModules[idx];
                  final active = m.key == _currentModule.key;
                  return ListTile(
                    leading: Icon(
                      m.iconData,
                      color: active ? AdminColors.gold : AdminColors.sky,
                    ),
                    title: Text(
                      m.title,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? AdminColors.gold : AdminColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      m.path,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openModule(m);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentModule.title,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _currentUrl.isNotEmpty ? _currentUrl : _currentModule.path,
                style: const TextStyle(
                  fontSize: 11,
                  color: AdminColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Pindah Modul',
              icon: const Icon(Icons.apps_rounded),
              onPressed: _showQuickSwitch,
            ),
            IconButton(
              tooltip: 'Muat Ulang / Tiket Baru',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _openModule(_currentModule),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'back' && await _controller.canGoBack()) {
                  await _controller.goBack();
                } else if (v == 'forward' && await _controller.canGoForward()) {
                  await _controller.goForward();
                } else if (v == 'browser') {
                  await _openExternal();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'back', child: Text('Mundur (Back)')),
                PopupMenuItem(value: 'forward', child: Text('Maju (Forward)')),
                PopupMenuItem(
                  value: 'browser',
                  child: Text('Buka di Browser Eksternal'),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: (_loadingTicket || (_progress > 0 && _progress < 100))
                ? LinearProgressIndicator(
                    value: _loadingTicket ? null : _progress / 100.0,
                    minHeight: 3,
                    backgroundColor: AdminColors.surface,
                    color: AdminColors.gold,
                  )
                : const SizedBox(height: 3),
          ),
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AdminColors.danger,
                        size: 46,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AdminColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openModule(_currentModule),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
