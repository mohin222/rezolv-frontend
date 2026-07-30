import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/real_station.dart';
import '../widgets/custom_bottom_nav.dart';

class HotelDetailScreen extends StatelessWidget {
  final RealHotel hotel;
  final String locationCode;
  final String locationCity;
  final List<String> dates;
  final Map<String, Map<String, int>> dailySplit;
  final ValueChanged<int> onNavigateToTab;

  const HotelDetailScreen({
    super.key,
    required this.hotel,
    required this.locationCode,
    required this.locationCity,
    required this.onNavigateToTab,
    this.dates = const [],
    this.dailySplit = const {},
  });

  static const _navy    = Color(0xFF0D2B4E);
  static const _darkRed = Color(0xFFC62828);
  static const _gold    = Color(0xFFC1791C);
  static const _iropsUrl = 'https://irrops.rezolv.app/web/login?redirect=%2Fweb%3F#action=617&model=gcs.pi.data&view_type=list&cids=1&menu_id=430';

  int get _gapRooms => (1000 - hotel.availableRooms).clamp(0, 1000);

  String _starString(String? star) {
    if (star == null) return '';
    try { return '★' * int.parse(double.parse(star).toStringAsFixed(0)); } catch (_) { return star; }
  }

  String get _sourceLabel {
    switch (hotel.hotelSource) {
      case 'channel_manager': return 'Channel Manager (CM)';
      case 'extranet':        return 'Manual (Extranet)';
      default:                return 'N/A';
    }
  }

  Future<void> _openIrrops() async {
    final uri = Uri.parse(_iropsUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMaps() async {
    if (hotel.address == null || hotel.address!.isEmpty) return;
    final query = Uri.encodeComponent('${hotel.hotelName}, ${hotel.address}');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone() async {
    if (hotel.phone == null) return;
    final uri = Uri.parse('tel:${hotel.phone}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendEmail() async {
    if (hotel.email == null) return;
    final raw = hotel.email!;
    final match = RegExp(r'<(.+?)>').firstMatch(raw);
    final emailAddr = match != null ? match.group(1)! : raw;
    final uri = Uri.parse('mailto:$emailAddr');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDay(DateTime d) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[d.weekday - 1];
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  void _handleNavTap(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    onNavigateToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme         = Theme.of(context);
    final isDark        = theme.brightness == Brightness.dark;
    final bg            = theme.scaffoldBackgroundColor;
    final cardBg        = theme.cardColor;
    final textPrimary   = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor   = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);
    final dividerColor  = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    final todayCm       = dates.isNotEmpty ? (dailySplit[dates[0]]?['cm']       ?? 0) : 0;
    final todayExtranet = dates.isNotEmpty ? (dailySplit[dates[0]]?['extranet']  ?? 0) : 0;
    final rawEmail      = hotel.email ?? '';
    final emailMatch    = RegExp(r'<(.+?)>').firstMatch(rawEmail);
    final emailAddr     = emailMatch != null ? emailMatch.group(1)! : rawEmail;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: CustomBottomNav(selectedIndex: 0, onTap: (i) => _handleNavTap(context, i)),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(context, cardBg, textPrimary),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Tags
              Wrap(spacing: 8, children: [
                _tag('$locationCode · $locationCity', isDark ? Colors.grey.shade800 : Colors.grey.shade100, textPrimary),
                if (hotel.anyStopsell) _tag('Stop Sell', const Color(0xFFFCE4E4), _darkRed),
                _tag(hotel.starCategory != null ? '${hotel.starCategory}★' : 'Unrated', const Color(0xFFFFF8E1), _gold),
              ]),
              const SizedBox(height: 10),

              Text(hotel.hotelName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 2),

              if (hotel.address != null && hotel.address!.isNotEmpty)
                GestureDetector(
                  onTap: _openMaps,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFFC1791C)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(hotel.address!, style: const TextStyle(fontSize: 11, color: Color(0xFFC1791C), height: 1.4, decoration: TextDecoration.none))),
                    ]),
                  ),
                ),

              const SizedBox(height: 6),
              Row(children: [
                Text(_starString(hotel.starCategory), style: const TextStyle(color: _gold, fontSize: 13)),
                if (hotel.starCategory != null)
                  Text('  ${hotel.starCategory}★', style: TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text('${hotel.availableRooms} rooms today', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                ),
              ]),
              const SizedBox(height: 14),

              // CM / EXTRANET / GAP ROOMS
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                child: Row(children: [
                  Expanded(child: _statBlock('$todayCm',       'CM',        _navy,    textSecondary)),
                  Container(width: 1, height: 32, color: borderColor),
                  Expanded(child: _statBlock('$todayExtranet', 'EXTRANET',  _gold,    textSecondary)),
                  Container(width: 1, height: 32, color: borderColor),
                  Expanded(child: _statBlock('$_gapRooms',     'GAP ROOMS', _darkRed, textSecondary)),
                ]),
              ),
              const SizedBox(height: 14),

              // Room Availability
              _sectionHeader('ROOM AVAILABILITY', textPrimary),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                child: Row(children: [
                  Expanded(child: _dayBox('Today', hotel.availableRooms)),
                  const SizedBox(width: 6),
                  Expanded(child: _dayBox('Tomorrow',  dates.length > 1 ? (dailySplit[dates[1]]?['cm'] ?? 0) + (dailySplit[dates[1]]?['extranet'] ?? 0) : 0)),
                  const SizedBox(width: 6),
                  Expanded(child: _dayBox('Day after', dates.length > 2 ? (dailySplit[dates[2]]?['cm'] ?? 0) + (dailySplit[dates[2]]?['extranet'] ?? 0) : 0)),
                ]),
              ),
              const SizedBox(height: 14),

              // Fix in RICH
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.build, size: 13),
                  label: const Text('Fix in RICH', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(height: 14),

              // Booking Volume
              _sectionHeader('BOOKING VOLUME', textPrimary),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openIrrops,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                  child: Row(children: [
                    Icon(Icons.assignment_outlined, size: 17, color: textSecondary),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('View 30-day booking volume in IRROPS', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: textPrimary)),
                      Text('Opens Rezolv IRROPS · filter by hotel name', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                    ])),
                    Icon(Icons.arrow_forward_ios, size: 13, color: textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 14),

              // Contact & Contract
              _sectionHeader('CONTACT & CONTRACT', textPrimary),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                child: Column(children: [
                  InkWell(
                    onTap: hotel.phone != null ? _callPhone : null,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(children: [
                        Icon(Icons.phone_outlined, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Phone', style: TextStyle(fontSize: 10, color: textSecondary, height: 1)),
                          const SizedBox(height: 2),
                          Text(hotel.phone ?? 'N/A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: hotel.phone != null ? textPrimary : textSecondary)),
                        ])),
                        if (hotel.phone != null) Icon(Icons.arrow_forward_ios, size: 11, color: textSecondary),
                      ]),
                    ),
                  ),
                  Divider(height: 1, indent: 42, color: dividerColor),
                  InkWell(
                    onTap: emailAddr.isNotEmpty ? _sendEmail : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(children: [
                        Icon(Icons.mail_outline, size: 16, color: _navy.withOpacity(0.7)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Email', style: TextStyle(fontSize: 10, color: textSecondary, height: 1)),
                          const SizedBox(height: 2),
                          Text(emailAddr.isNotEmpty ? emailAddr : 'N/A', overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: emailAddr.isNotEmpty ? textPrimary : textSecondary)),
                        ])),
                        if (emailAddr.isNotEmpty) Icon(Icons.arrow_forward_ios, size: 11, color: textSecondary),
                      ]),
                    ),
                  ),
                  Divider(height: 1, indent: 42, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Icon(Icons.swap_horiz_rounded, size: 16, color: _gold),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Source', style: TextStyle(fontSize: 10, color: textSecondary, height: 1)),
                        const SizedBox(height: 2),
                        Text(_sourceLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hotel.hotelSource == 'channel_manager' ? const Color(0xFFE8F0FB) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hotel.hotelSource == 'channel_manager' ? 'CM' : 'EXT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hotel.hotelSource == 'channel_manager' ? _navy : _gold),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // 7-Day CM vs Extranet
              if (dates.isNotEmpty) ...[
                _sectionHeader('7-DAY CM VS EXTRANET', textPrimary),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text('DATE',     style: GoogleFonts.robotoMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5))),
                        Expanded(flex: 2, child: Text('CM',       textAlign: TextAlign.center, style: GoogleFonts.robotoMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: _navy, letterSpacing: 0.5))),
                        Expanded(flex: 2, child: Text('EXTRANET', textAlign: TextAlign.center, style: GoogleFonts.robotoMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: _gold, letterSpacing: 0.5))),
                      ]),
                    ),
                    ...dates.asMap().entries.map((entry) {
                      final i        = entry.key;
                      final dateStr  = entry.value;
                      final split    = dailySplit[dateStr];
                      final cm       = split?['cm']       ?? 0;
                      final extranet = split?['extranet'] ?? 0;
                      final day      = DateTime.tryParse(dateStr) ?? DateTime.now().add(Duration(days: i));
                      final isToday  = i == 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: isToday ? (isDark ? const Color(0xFF1A2035) : const Color(0xFFF0F4FF)) : cardBg,
                          border: i < dates.length - 1 ? Border(bottom: BorderSide(color: dividerColor)) : null,
                          borderRadius: i == dates.length - 1 ? const BorderRadius.vertical(bottom: Radius.circular(10)) : null,
                        ),
                        child: Row(children: [
                          Expanded(flex: 3, child: Row(children: [
                            if (isToday) Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(4)),
                              child: const Text('TODAY', style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_formatDay(day), style: TextStyle(fontSize: 8.5, color: textSecondary)),
                              Text(_formatDate(day), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                            ]),
                          ])),
                          Expanded(flex: 2, child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: cm > 0 ? const Color(0xFFE8F0FB) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$cm', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cm > 0 ? _navy : textSecondary)),
                          )),
                          Expanded(flex: 2, child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: extranet > 0 ? const Color(0xFFFFF3E0) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$extranet', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: extranet > 0 ? _gold : textSecondary)),
                          )),
                        ]),
                      );
                    }),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color cardBg, Color textPrimary) {
    return Container(
      color: cardBg,
      child: Column(children: [
                        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: _navy, size: 20), onPressed: () => Navigator.pop(context)),
            Expanded(child: Text(hotel.hotelName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(String label, Color bg, Color fg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  Widget _statBlock(String value, String label, Color valueColor, Color labelColor) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 8.5, color: labelColor), textAlign: TextAlign.center),
    ]);
  }

  Widget _sectionHeader(String title, Color textColor) {
    return Row(children: [
      Container(width: 3, height: 13, color: _navy, margin: const EdgeInsets.only(right: 8)),
      Text(title, style: GoogleFonts.robotoMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5)),
    ]);
  }

  Widget _dayBox(String label, int rooms) {
    final isEmpty = rooms == 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isEmpty ? const Color(0xFFFCE4E4) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
        const SizedBox(height: 3),
        Text('$rooms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isEmpty ? _darkRed : Colors.green)),
      ]),
    );
  }
}