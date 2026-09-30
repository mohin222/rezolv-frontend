import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/real_station.dart';
import '../providers/theme_provider.dart';
import '../data/api_config.dart';
import 'login_screen.dart';
import '../utils/app_version.dart';

class RealMoreScreen extends StatefulWidget {
  final List<RealStation> stations;
  final bool loading;
  final String? error;
  final DateTime lastFetched;
  final Future<void> Function({String? fromDate, String? toDate}) onReload;
  final ValueChanged<int> onNavigateToTab;

  const RealMoreScreen({
    super.key,
    required this.stations,
    required this.loading,
    required this.error,
    required this.lastFetched,
    required this.onReload,
    required this.onNavigateToTab,
  });

  @override
  State<RealMoreScreen> createState() => _RealMoreScreenState();
}

class _RealMoreScreenState extends State<RealMoreScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  String _username = '';
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final username = await ApiConfig.getUsername();
    final email    = await ApiConfig.getEmail();
    final phone    = await ApiConfig.getPhone();
    if (!mounted) return;
    setState(() {
      _username = username;
      _email    = email;
      _phone    = phone;
    });
  }

  String get _syncLabel {
    final now = DateTime.now();
    final diff = now.difference(widget.lastFetched);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  int get _totalActiveHotels => widget.stations.fold(0, (sum, s) => sum + s.hotelCount);
  int get _totalRoomsAvailable => widget.stations.fold(0, (sum, s) => sum + s.roomsToday);

  int get _soldOutHotels {
    var count = 0;
    for (final station in widget.stations) {
      count += station.hotels.where((h) => h.availableRooms == 0).length;
    }
    return count;
  }

  int get _stopsellHotels {
    var count = 0;
    for (final station in widget.stations) {
      count += station.hotels.where((h) => h.anyStopsell).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isDark),
            Expanded(child: _buildBody(context, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey;

    return Container(
      color: cardBg,
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
              Text('Rezolv', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              Text('More · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey)),
            ])),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: _navy),
              onPressed: () => widget.onReload(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (widget.loading) return const Center(child: CircularProgressIndicator(color: _navy));

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 40),
              const SizedBox(height: 10),
              Text(widget.error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => widget.onReload(),
                style: ElevatedButton.styleFrom(backgroundColor: _navy),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final themeProvider = context.watch<ThemeProvider>();
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final labelColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProfileCard(isDark, cardBg, textPrimary, textSecondary),
        const SizedBox(height: 20),
        _sectionLabel('DATA STATUS', labelColor),
        _card(cardBg, dividerColor, isDark: isDark, [
          _row('Last sync', _syncLabel, textSecondary, textPrimary, icon: Icons.schedule_rounded, iconColor: _navy),
          _row('Active stations', '${widget.stations.length}', textSecondary, textPrimary, icon: Icons.flight_takeoff_rounded, iconColor: _gold),
          _row('Total hotels', '$_totalActiveHotels', textSecondary, textPrimary, icon: Icons.hotel_rounded, iconColor: _navy),
        ]),
        const SizedBox(height: 20),
        _sectionLabel("TODAY'S SNAPSHOT", labelColor),
        _card(cardBg, dividerColor, isDark: isDark, [
          _row('Total available rooms', '$_totalRoomsAvailable', textSecondary, const Color(0xFF1B7A3D),
              icon: Icons.king_bed_rounded, iconColor: const Color(0xFF1B7A3D)),
          InkWell(
            onTap: () => widget.onNavigateToTab(1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: const Color(0xFFC62828).withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                  child: const Center(child: Icon(Icons.report_gmailerrorred_rounded, size: 13, color: Color(0xFFC62828))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Sold out / Stop-sell', style: TextStyle(fontSize: 13.5, color: textSecondary)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text('$_soldOutHotels', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC62828))),
                      Text(' sold out', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                      Text('  ·  ', style: TextStyle(color: textSecondary)),
                      Text('$_stopsellHotels', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                      Text(' stop-sell', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                    ]),
                  ]),
                ),
                Icon(Icons.chevron_right, size: 16, color: textSecondary),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        _sectionLabel('ACTIONS', labelColor),
        _card(cardBg, dividerColor, isDark: isDark, [
          _actionRow(
            icon: Icons.refresh_rounded, iconColor: _navy, label: 'Reload app',
            textColor: textPrimary, trailingColor: textSecondary,
            onTap: () => widget.onReload(),
          ),
          _actionRow(
            icon: Icons.dark_mode_rounded, iconColor: _gold, label: 'Dark mode',
            textColor: textPrimary, trailingColor: textSecondary,
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) => context.read<ThemeProvider>().toggleDarkMode(value),
              activeColor: _gold,
            ),
          ),
          _actionRow(
            icon: Icons.ios_share_rounded, iconColor: _navy, label: 'Share network summary',
            textColor: textPrimary, trailingColor: textSecondary,
            onTap: () => Share.share(
              'Rezolv Inventory · Live Snapshot\n'
                  '$_totalActiveHotels hotels across ${widget.stations.length} stations\n'
                  '$_totalRoomsAvailable rooms available right now\n'
                  '$_soldOutHotels sold out, $_stopsellHotels on stop-sell',
            ),
          ),
        ]),
        const SizedBox(height: 20),
        _sectionLabel('ABOUT', labelColor),
        _card(cardBg, dividerColor, isDark: isDark, [
          _row('App', 'Rezolv Inventory', textSecondary, textPrimary, icon: Icons.apps_rounded, iconColor: _navy),
          _row('Version', AppVersion.version, textSecondary, textPrimary, icon: Icons.new_releases_rounded, iconColor: _gold),
        ]),
        const SizedBox(height: 20),
        _sectionLabel('ACCOUNT', labelColor),
        _card(cardBg, dividerColor, isDark: isDark, [
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
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                  child: const Center(child: Icon(Icons.logout_rounded, size: 13, color: Colors.red)),
                ),
                const SizedBox(width: 10),
                const Text('Logout', style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 30),
      ],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
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

  Widget _card(Color cardBg, Color dividerColor, List<Widget> children, {bool isDark = false}) {
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
        border: Border.all(color: dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: spacedChildren),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          if (icon != null) ...[
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: (iconColor ?? _navy).withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
              child: Center(child: Icon(icon, size: 13, color: iconColor ?? _navy)),
            ),
            const SizedBox(width: 10),
          ],
          Text(label, style: TextStyle(fontSize: 13.5, color: labelColor)),
        ]),
        Flexible(child: Text(value, textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: valueColor))),
      ]),
    );
  }

  Widget _actionRow({required IconData icon, required Color iconColor, required String label, required Color textColor, required Color trailingColor, Widget? trailing, VoidCallback? onTap}) {
    final content = SizedBox(
      height: 48,
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Icon(icon, size: 15, color: iconColor)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: textColor))),
        trailing ?? Icon(Icons.chevron_right, size: 18, color: trailingColor),
      ]),
    );
    return onTap != null ? InkWell(onTap: onTap, child: content) : content;
  }
}