import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_repository.dart';
import '../utils/error_messages.dart';

class FlightRiskDetailScreen extends StatefulWidget {
  final String stationCode;
  final String stationCity;

  const FlightRiskDetailScreen({
    super.key,
    required this.stationCode,
    required this.stationCity,
  });

  @override
  State<FlightRiskDetailScreen> createState() => _FlightRiskDetailScreenState();
}

class _FlightRiskDetailScreenState extends State<FlightRiskDetailScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);
  static const _red = Color(0xFFC62828);

  static final DateFormat _dateFmt = DateFormat('EEE, d MMM');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tomorrow = [];
  List<Map<String, dynamic>> _week = [];

  static const _infoSeenKey = 'flight_risk_info_seen';

  @override
  void initState() {
    super.initState();
    _load();
    _maybeAutoShowInfo();
  }

  Future<void> _maybeAutoShowInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_infoSeenKey) == true) return;
    await prefs.setBool(_infoSeenKey, true);
    if (!mounted) return;
    // Let the first frame settle before popping a sheet on top of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final theme = Theme.of(context);
      _showInfoSheet(
        context,
        theme.cardColor,
        theme.brightness == Brightness.dark,
        theme.colorScheme.onSurface,
        theme.colorScheme.onSurface.withOpacity(0.55),
      );
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiRepository().fetchFlightRiskStationDetail(widget.stationCode);
      setState(() {
        _tomorrow = (data['tomorrow'] as List? ?? []).cast<Map<String, dynamic>>();
        _week = (data['week'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(child: Text('Flights at Risk', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary))),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showInfoSheet(context, cardBg, isDark, textPrimary, textSecondary),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: _gold.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.info_outline_rounded, color: _gold, size: 18),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary, size: 20),
                onPressed: _load,
              ),
            ]),
          ),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: _navy)))
          else if (_error != null)
            Expanded(child: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.wifi_off_rounded, color: textSecondary, size: 40),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: _navy), child: const Text('Retry', style: TextStyle(color: Colors.white))),
              ]),
            )))
          else
            Expanded(
              child: RefreshIndicator(
                color: _navy,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _header(),
                    const SizedBox(height: 20),
                    _sectionHeader('TOMORROW', _tomorrow.length, textSecondary),
                    const SizedBox(height: 8),
                    _flightList(_tomorrow, cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),
                    _sectionHeader('COMING 5 DAYS', _week.length, textSecondary),
                    const SizedBox(height: 8),
                    _flightList(_week, cardBg, borderColor, textPrimary, textSecondary),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1C1C1E), Color(0xFF20344A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.stationCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(widget.stationCity, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
        ])),
        _headerStat('${_tomorrow.length}', 'Tomorrow'),
        const SizedBox(width: 22),
        _headerStat('${_week.length}', 'Coming 5 Days'),
      ]),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
    ]);
  }

  void _showInfoSheet(BuildContext context, Color cardBg, bool isDark, Color textPrimary, Color textSecondary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).viewPadding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 18),
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.info_outline_rounded, size: 18, color: _gold)),
            ),
            const SizedBox(width: 12),
            Text('About This Data', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          ]),
          const SizedBox(height: 18),
          _infoRow(Icons.source_outlined, 'Source', 'Think Lumo\'s departure delay forecast, updated whenever an admin uploads a fresh CSV export — not generated inside the app.', textPrimary, textSecondary),
          const SizedBox(height: 14),
          _infoRow(Icons.query_stats_rounded, 'Risk percentages', 'The chance a flight departs at least 30, 90, or 180 minutes late, taken directly from that export.', textPrimary, textSecondary),
          const SizedBox(height: 14),
          _infoRow(Icons.hotel_outlined, 'Why it matters', 'A high-risk flight can mean crew or passengers need last-minute rooms at this station — plan availability accordingly.', textPrimary, textSecondary),
          const SizedBox(height: 14),
          _infoRow(Icons.calendar_today_outlined, 'Tomorrow / Coming 5 Days', 'The same time window shown on the Overview screen\'s station cards.', textPrimary, textSecondary),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: _navy, padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String body, Color textPrimary, Color textSecondary) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 2),
        Text(body, style: TextStyle(fontSize: 11.5, height: 1.4, color: textSecondary)),
      ])),
    ]);
  }

  Widget _sectionHeader(String label, int count, Color textSecondary) {
    return Row(children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.8)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _gold)),
      ),
    ]);
  }

  Widget _flightList(List<Map<String, dynamic>> flights, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    if (flights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
        child: Center(child: Text('No flights at risk', style: TextStyle(fontSize: 13, color: textSecondary))),
      );
    }
    return Column(children: [
      for (final f in flights) ...[
        _flightCard(f, cardBg, borderColor, textPrimary, textSecondary),
        const SizedBox(height: 10),
      ],
    ]);
  }

  DateTime? _parseRawDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw.trim().replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  Widget _flightCard(Map<String, dynamic> flight, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final flightNumber = (flight['flight_number'] as String?)?.trim();
    final airline = flight['airline'] as String?;
    final departure = _parseRawDateTime(flight['departure_time'] as String?);

    final rawFields = (flight['raw'] as Map?)?.cast<String, dynamic>() ?? {};
    String? destination;
    DateTime? arrival;
    double? p30, p90, p180;
    for (final entry in rawFields.entries) {
      final key = entry.key.toLowerCase().trim();
      final value = '${entry.value}';
      if (destination == null && key.contains('destination')) destination = value;
      if (arrival == null && key.contains('arrival')) arrival = _parseRawDateTime(value);
      if (p30 == null && key == 'p 30') p30 = double.tryParse(value);
      if (p90 == null && key == 'p 90') p90 = double.tryParse(value);
      if (p180 == null && key == 'p 180') p180 = double.tryParse(value);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Flight number + airline + date (shown once, here, not repeated below)
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
            child: const Center(child: Icon(Icons.flight_takeoff, size: 16, color: _gold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Row(children: [
            Text(
              (flightNumber == null || flightNumber.isEmpty) ? 'Flight number unavailable' : flightNumber,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            if (airline != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: textSecondary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(airline, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textSecondary)),
              ),
            ],
          ])),
          if (departure != null)
            Text(_dateFmt.format(departure), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSecondary)),
        ]),
        const SizedBox(height: 12),

        // Route — times only, no date (date is already shown above)
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.stationCode, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 2),
            Text('DEPARTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.6)),
            Text(
              departure != null ? _timeFmt.format(departure) : '—',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
            ),
          ])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: textSecondary),
          ),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(destination ?? '—', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 2),
            Text('ARRIVES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.6)),
            Text(
              arrival != null ? _timeFmt.format(arrival) : '—',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
              textAlign: TextAlign.end,
            ),
          ])),
        ]),
        const SizedBox(height: 12),

        // Delay risk — 30, 90 and 180 minute buckets, in one neat row
        if (p30 != null || p90 != null || p180 != null)
          Row(children: [
            if (p30 != null) Expanded(child: _delayBadge('30 min', p30)),
            if (p30 != null && (p90 != null || p180 != null)) const SizedBox(width: 8),
            if (p90 != null) Expanded(child: _delayBadge('90 min', p90)),
            if (p90 != null && p180 != null) const SizedBox(width: 8),
            if (p180 != null) Expanded(child: _delayBadge('180 min', p180)),
          ]),
      ]),
    );
  }

  Widget _delayBadge(String label, double pct) {
    final color = pct >= 50 ? _red : _gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 5),
        Text('risk >$label', style: TextStyle(fontSize: 10, color: color)),
      ]),
    );
  }
}
