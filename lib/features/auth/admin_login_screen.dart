import 'package:flutter/material.dart';

import '../../core/admin_session.dart';
import '../../core/admin_theme.dart';
import '../../models/admin_models.dart';
import '../../services/bt_admin_api.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.onAuthenticated,
  });

  final void Function(AdminSession session, AdminDashboardData dashboard)
      onAuthenticated;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noregCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _api = BtAdminApi();

  bool _loading = false;
  bool _sendingOtp = false;
  bool _obscure = true;
  String? _statusMsg;
  bool _isError = false;

  @override
  void dispose() {
    _noregCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _statusMsg = null;
    });
    try {
      final res = await _api.login(
        noreg: _noregCtrl.text,
        secret: _secretCtrl.text,
      );
      await AdminSessionStore().save(res.session);
      if (!mounted) return;
      widget.onAuthenticated(res.session, res.dashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _statusMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestOtp() async {
    final noreg = _noregCtrl.text.trim();
    if (noreg.isEmpty) {
      setState(() {
        _isError = true;
        _statusMsg = 'Masukkan Noreg terlebih dahulu untuk kirim OTP WA.';
      });
      return;
    }
    setState(() {
      _sendingOtp = true;
      _statusMsg = null;
    });
    try {
      final msg = await _api.requestOtpWa(noreg: noreg);
      if (!mounted) return;
      setState(() {
        _isError = false;
        _statusMsg = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _statusMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1830), AdminColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          gradient: AdminColors.heroGradient,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AdminColors.gold.withValues(alpha: 0.65),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AdminColors.gold.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Image.asset('assets/img/appicon.png'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AdminColors.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AdminColors.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'EXECUTIVE COMMAND CENTER',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.gold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'BTadmin Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PUK SP LEM SPSI PT. TMMIN • Admin Panel Mobile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_statusMsg != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (_isError
                                            ? AdminColors.danger
                                            : AdminColors.emerald)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isError
                                          ? AdminColors.danger
                                          : AdminColors.emerald,
                                    ),
                                  ),
                                  child: Text(
                                    _statusMsg!,
                                    style: TextStyle(
                                      color: _isError
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFF6EE7B7),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _noregCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Noreg Admin',
                                  hintText: 'Contoh: 00415024',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Noreg wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _secretCtrl,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'PIN / Password / OTP WA',
                                  hintText: 'Masukkan PIN atau kode OTP 6 digit',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'PIN / Password / OTP wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: (_sendingOtp || _loading)
                                      ? null
                                      : _requestOtp,
                                  icon: _sendingOtp
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.chat_outlined,
                                          size: 16),
                                  label: const Text('Kirim OTP WhatsApp'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _loading ? null : _submit,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: AdminColors.bg,
                                          ),
                                        )
                                      : const Icon(Icons.verified_user_rounded),
                                  label: Text(
                                    _loading
                                        ? 'Memverifikasi Akses...'
                                        : 'Masuk Command Center',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
