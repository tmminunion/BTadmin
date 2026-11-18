import 'package:flutter/material.dart';

import 'core/admin_session.dart';
import 'core/admin_theme.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/shell/admin_shell_screen.dart';
import 'models/admin_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BtAdminApp());
}

class BtAdminApp extends StatefulWidget {
  const BtAdminApp({super.key});

  @override
  State<BtAdminApp> createState() => _BtAdminAppState();
}

class _BtAdminAppState extends State<BtAdminApp> {
  final _store = AdminSessionStore();
  AdminSession? _session;
  AdminDashboardData? _initialDash;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final s = await _store.load();
    if (!mounted) return;
    setState(() {
      _session = s;
      _ready = true;
    });
  }

  Future<void> _logout() async {
    await _store.clear();
    if (!mounted) return;
    setState(() {
      _session = null;
      _initialDash = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BTadmin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: !_ready
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AdminColors.gold),
              ),
            )
          : _session == null
              ? AdminLoginScreen(
                  onAuthenticated: (s, dash) {
                    setState(() {
                      _session = s;
                      _initialDash = dash;
                    });
                  },
                )
              : AdminShellScreen(
                  session: _session!,
                  initialDashboard: _initialDash,
                  onLogout: _logout,
                ),
    );
  }
}
