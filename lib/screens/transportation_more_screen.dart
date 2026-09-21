import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../data/api_config.dart';
import '../data/api_repository.dart';
import 'login_screen.dart';
import '../utils/app_version.dart';

class TransportationMoreScreen extends StatefulWidget {
  const TransportationMoreScreen({super.key});

  @override
  State<TransportationMoreScreen> createState() => _TransportationMoreScreenState();
}

class _TransportationMoreScreenState extends State<TransportationMoreScreen> {
  static const _navy = Color(0xFF1C1C1E);
  static const _gold = Color(0xFF6E6E6E);

  String _username = '';
  String _email = '';
  String _phone = '';
  bool _loading = true;
  int _stationsWithVehicles = 0;
  int _totalVehicles = 0;
  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadStats();
  }

  Future<void> _loadUserInfo() async {
    final username = await ApiConfig.getUsername();
    final email = await ApiConfig.getEmail();
    final phone = await ApiConfig.getPhone();
    if (!mounted) return;
    setState(() {
      _username = username;
      _email = email;
      _phone = phone;
    });
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final rows = await ApiRepository().fetchTransportationOverview();
      if (!mounted) return;
      final totalVehicles = rows.fold<int>(0, (s, r) => s + ((r['total'] as num?)?.toInt() ?? 0));
      final withVehicles = rows.where((r) => ((r['total'] as num?)?.toInt() ?? 0) > 0).length;
      setState(() {
        _totalVehicles = totalVehicles;
        _stationsWithVehicles = withVehicles;
        _lastSync = DateTime.now();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _syncLabel {
    final diff = DateTime.now().difference(_lastSync);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final labelColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(9)),
                child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rezolv', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                Text('More · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),
              ])),
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: textPrimary),
                onPressed: _loadStats,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileCard(isDark, cardBg, textPrimary, textSecondary),
                const SizedBox(height: 20),
                _sectionLabel('DATA STATUS', labelColor),
                _card(cardBg, dividerColor, [
                  _row('Last sync', _loading ? 'Syncing...' : _syncLabel, textSecondary, textPrimary),
                  _row('Stations with vehicles', '$_stationsWithVehicles of 8', textSecondary, textPrimary),
                  _row('Total vehicles live', '$_totalVehicles', textSecondary, const Color(0xFF1B7A3D)),
                ]),
                const SizedBox(height: 20),
                _sectionLabel('ACTIONS', labelColor),
                _card(cardBg, dividerColor, [
                  InkWell(
                    onTap: _loadStats,
                    child: SizedBox(
                      height: 48,
                      child: Row(children: [
                        Icon(Icons.refresh, size: 20, color: textPrimary),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Reload data', style: TextStyle(fontSize: 14, color: textPrimary))),
                        Icon(Icons.chevron_right, size: 18, color: textSecondary),
                      ]),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Row(children: [
                      Icon(Icons.dark_mode_outlined, size: 20, color: textPrimary),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Dark mode', style: TextStyle(fontSize: 14, color: textPrimary))),
                      Switch(
                        value: isDark,
                        onChanged: (value) => context.read<ThemeProvider>().toggleDarkMode(value),
                        activeColor: _gold,
                      ),
                    ]),
                  ),
                  InkWell(
                    onTap: () {
                      Share.share(
                        'Rezolv Transportation · Live Snapshot\n'
                        '$_totalVehicles vehicles across $_stationsWithVehicles of 8 stations',
                      );
                    },
                    child: SizedBox(
                      height: 48,
                      child: Row(children: [
                        Icon(Icons.share, size: 20, color: textPrimary),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Share network summary', style: TextStyle(fontSize: 14, color: textPrimary))),
                        Icon(Icons.chevron_right, size: 18, color: textSecondary),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                _sectionLabel('ABOUT', labelColor),
                _card(cardBg, dividerColor, [
                  _row('App', 'Rezolv Transportation', textSecondary, textPrimary),
                  _row('Version', AppVersion.version, textSecondary, textPrimary),
                  _row('Data source', 'RIDE Ops (live)', textSecondary, textPrimary),
                ]),
                const SizedBox(height: 20),
                _sectionLabel('ACCOUNT', labelColor),
                _card(cardBg, dividerColor, [
                  InkWell(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: cardBg,
                          title: Text('Logout', style: TextStyle(color: textPrimary)),
                          content: Text('Are you sure you want to logout?', style: TextStyle(color: textSecondary)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: textSecondary))),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ApiConfig.clearToken();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: const [
                        Icon(Icons.logout, size: 20, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Logout', style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildProfileCard(bool isDark, Color cardBg, Color textPrimary, Color textSecondary) {
    final initials = _username.isNotEmpty
        ? _username.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : 'RO';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(26)),
            child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _username.isNotEmpty ? _username : 'Rezolv Operations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.circle, size: 6, color: Colors.green.shade600),
                const SizedBox(width: 5),
                Text('Signed in · $_syncLabel', style: TextStyle(fontSize: 11, color: textSecondary)),
              ]),
            ]),
          ),
        ]),
        if (_email.isNotEmpty || _phone.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED)),
          const SizedBox(height: 10),
          if (_email.isNotEmpty)
            Row(children: [
              Icon(Icons.email_outlined, size: 14, color: textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(_email, style: TextStyle(fontSize: 12, color: textSecondary))),
            ]),
          if (_email.isNotEmpty && _phone.isNotEmpty) const SizedBox(height: 6),
          if (_phone.isNotEmpty)
            Row(children: [
              Icon(Icons.phone_outlined, size: 14, color: textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(_phone, style: TextStyle(fontSize: 12, color: textSecondary))),
            ]),
        ],
      ]),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: GoogleFonts.robotoMono(fontSize: 10.5, color: color, letterSpacing: 0.8)),
    );
  }

  Widget _card(Color cardBg, Color dividerColor, List<Widget> children) {
    final spacedChildren = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i != children.length - 1) {
        spacedChildren.add(Divider(height: 1, color: dividerColor));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: spacedChildren),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13.5, color: labelColor)),
        Flexible(child: Text(value, textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: valueColor))),
      ]),
    );
  }
}
