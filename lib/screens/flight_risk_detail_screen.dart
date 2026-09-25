import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

  static final DateFormat _dateFmt = DateFormat('EEE, d MMM');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tomorrow = [];
  List<Map<String, dynamic>> _week = [];

  @override
  void initState() {
    super.initState();
    _load();
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
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Flights at Risk', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          Text('${widget.stationCode} · ${widget.stationCity}', style: TextStyle(fontSize: 11, color: textSecondary)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.wifi_off_rounded, color: textSecondary, size: 40),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: _navy), child: const Text('Retry', style: TextStyle(color: Colors.white))),
                  ]),
                ))
              : RefreshIndicator(
                  color: _navy,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionHeader('TOMORROW', _tomorrow.length, textSecondary),
                      const SizedBox(height: 8),
                      _flightList(_tomorrow, cardBg, borderColor, textPrimary, textSecondary),
                      const SizedBox(height: 24),
                      _sectionHeader('COMING 5 DAYS', _week.length, textSecondary),
                      const SizedBox(height: 8),
                      _flightList(_week, cardBg, borderColor, textPrimary, textSecondary),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
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
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Column(children: [
        for (int i = 0; i < flights.length; i++) ...[
          if (i > 0) Divider(height: 1, color: borderColor),
          _flightRow(flights[i], textPrimary, textSecondary),
        ],
      ]),
    );
  }

  Widget _flightRow(Map<String, dynamic> flight, Color textPrimary, Color textSecondary) {
    final flightNumber = (flight['flight_number'] as String?)?.trim();
    final airline = flight['airline'] as String?;
    DateTime? departure;
    try {
      final raw = flight['departure_time'] as String?;
      if (raw != null) departure = DateTime.parse(raw);
    } catch (_) {}

    final rawFields = (flight['raw'] as Map?)?.cast<String, dynamic>() ?? {};
    String? destination;
    String? delayChance;
    for (final entry in rawFields.entries) {
      final key = entry.key.toLowerCase();
      if (destination == null && key.contains('destination')) {
        destination = '${entry.value}';
      }
      if (delayChance == null && key.contains('30m')) {
        delayChance = '${entry.value}';
      }
    }
    double? delayChancePct;
    if (delayChance != null) delayChancePct = double.tryParse(delayChance);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (departure != null)
          Row(children: [
            Text('SCHEDULED DEPARTURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.6)),
            const SizedBox(width: 8),
            Text(_timeFmt.format(departure), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(width: 6),
            Text(_dateFmt.format(departure), style: TextStyle(fontSize: 12, color: textSecondary)),
          ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Icon(Icons.flight_takeoff, size: 17, color: _gold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                (flightNumber == null || flightNumber.isEmpty) ? 'Flight number unavailable' : flightNumber,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              if (destination != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 12, color: textSecondary),
                const SizedBox(width: 6),
                Text(destination, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
              ],
            ]),
            if (airline != null) ...[
              const SizedBox(height: 2),
              Text(airline, style: TextStyle(fontSize: 11.5, color: textSecondary)),
            ],
          ])),
          if (delayChancePct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('${delayChancePct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _gold)),
                const Text('delay risk', style: TextStyle(fontSize: 9, color: _gold)),
              ]),
            ),
        ]),
      ]),
    );
  }
}
