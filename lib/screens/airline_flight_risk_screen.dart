import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/api_repository.dart';
import '../utils/error_messages.dart';

class AirlineFlightRiskScreen extends StatefulWidget {
  final String airlineCode;
  final String airlineName;

  const AirlineFlightRiskScreen({
    super.key,
    required this.airlineCode,
    required this.airlineName,
  });

  @override
  State<AirlineFlightRiskScreen> createState() => _AirlineFlightRiskScreenState();
}

class _AirlineFlightRiskScreenState extends State<AirlineFlightRiskScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  static final DateFormat _dateFmt = DateFormat('EEE, d MMM');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _stations = [];
  Map<String, String> _stationCities = {};
  int _networkStationCount = 0;
  DateTime? _computedAt;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final codes = await ApiRepository().fetchAirportCodes();
      final cities = {
        for (final c in codes)
          (c['code'] as String): (c['city'] as String? ?? '')
      };
      final data = await ApiRepository().fetchAirlineFlightRisk(widget.airlineCode);
      if (data == null) {
        setState(() { _error = 'Could not load flight risk for this airline.'; _loading = false; });
        return;
      }
      final computedAtRaw = data['computed_at'] as String?;
      final rawStations = (data['stations'] as List? ?? []).cast<Map<String, dynamic>>();
      final filteredStations = <Map<String, dynamic>>[];
      for (final st in rawStations) {
        final week = ((st['week'] as List? ?? []).cast<Map<String, dynamic>>()).where(_meetsRiskThreshold).toList();
        if (week.isEmpty) continue;
        final tomorrow = ((st['tomorrow'] as List? ?? []).cast<Map<String, dynamic>>()).where(_meetsRiskThreshold).toList();
        filteredStations.add({...st, 'week': week, 'tomorrow': tomorrow});
      }
      setState(() {
        _stationCities = cities;
        _stations = filteredStations;
        _networkStationCount = (data['network_station_count'] as num?)?.toInt() ?? 0;
        _computedAt = computedAtRaw != null ? DateTime.tryParse(computedAtRaw)?.toLocal() : null;
        _pending = data['pending'] == true;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  int get _totalAtRisk => _stations.fold<int>(0, (s, st) => s + ((st['week'] as List?)?.length ?? 0));

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
              Expanded(child: Text(widget.airlineName, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary), overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary, size: 20),
                onPressed: _loading ? null : _load,
              ),
            ]),
          ),
          if (_loading)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: _navy),
                  const SizedBox(height: 16),
                  Text('Loading ${widget.airlineName}\'s risk data…',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: textSecondary)),
                ]),
              ),
            )
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
                    _header(textSecondary),
                    const SizedBox(height: 18),
                    if (_pending)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Center(child: Text('Still checking ${widget.airlineName}\'s full network for the first time — this runs in the background every ~25 minutes. Check back shortly.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textSecondary))),
                      )
                    else if (_stations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Center(child: Text('No at-risk flights for ${widget.airlineName} across its network right now.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textSecondary))),
                      )
                    else
                      for (final st in _stations) ...[
                        _stationSection(st, cardBg, borderColor, textPrimary, textSecondary),
                        const SizedBox(height: 20),
                      ],
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _header(Color textSecondary) {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.airlineCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(widget.airlineName, style: const TextStyle(fontSize: 12.5, color: Colors.white70), overflow: TextOverflow.ellipsis),
          ])),
          _headerStat(_pending ? '—' : '$_networkStationCount', 'Stations Flown'),
          const SizedBox(width: 18),
          _headerStat(_pending ? '—' : '${_stations.length}', 'At Risk Now'),
          const SizedBox(width: 18),
          _headerStat(_pending ? '—' : '$_totalAtRisk', 'Flights (5d)'),
        ]),
        if (_computedAt != null) ...[
          const SizedBox(height: 10),
          Text('Updated ${_timeFmt.format(_computedAt!)}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ]),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
    ]);
  }

  Widget _stationSection(Map<String, dynamic> station, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final code = (station['station'] as String?) ?? '';
    final city = _stationCities[code] ?? '';
    final flights = (station['week'] as List? ?? []).cast<Map<String, dynamic>>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(code, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPrimary)),
        if (city.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text('· $city', style: TextStyle(fontSize: 12, color: textSecondary)),
        ],
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Text('${flights.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _gold)),
        ),
      ]),
      const SizedBox(height: 8),
      Column(children: [
        for (final f in flights) ...[
          _flightCard(f, code, cardBg, borderColor, textPrimary, textSecondary),
          const SizedBox(height: 10),
        ],
      ]),
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

  static num? _p90Of(Map<String, dynamic> flight) {
    final rawFields = (flight['raw'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final entry in rawFields.entries) {
      if (entry.key.toLowerCase().trim() == 'p 90') return entry.value as num?;
    }
    return null;
  }

  // Only flights whose displayed delay-chance badge is 50% or higher.
  static bool _meetsRiskThreshold(Map<String, dynamic> flight) {
    final p90 = _p90Of(flight);
    if (p90 == null) return false;
    return (p90 + 20).clamp(0, 100) >= 70;
  }

  Widget _flightCard(Map<String, dynamic> flight, String originCode, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final flightNumber = (flight['flight_number'] as String?)?.trim();
    final departure = _parseRawDateTime(flight['departure_time'] as String?);
    final delayReason = flight['delay_reason'] as String?;
    final rawFields = (flight['raw'] as Map?)?.cast<String, dynamic>() ?? {};
    String? destination;
    DateTime? arrival;
    num? p90;
    for (final entry in rawFields.entries) {
      final key = entry.key.toLowerCase().trim();
      final value = '${entry.value}';
      if (destination == null && key.contains('destination')) destination = value;
      if (arrival == null && key.contains('arrival')) arrival = _parseRawDateTime(value);
      if (p90 == null && key == 'p 90') p90 = entry.value as num?;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
            child: const Center(child: Icon(Icons.flight_takeoff, size: 16, color: _gold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            (flightNumber == null || flightNumber.isEmpty) ? 'Flight number unavailable' : flightNumber,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
          )),
          if (departure != null)
            Text(_dateFmt.format(departure), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: textSecondary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(originCode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
            const SizedBox(height: 2),
            Text('DEPARTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: 0.6)),
            Text(
              departure != null ? _timeFmt.format(departure) : '—',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: textPrimary),
            ),
          ])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: textSecondary),
          ),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(destination ?? '—', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
            const SizedBox(height: 2),
            Text('ARRIVES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: 0.6)),
            Text(
              arrival != null ? _timeFmt.format(arrival) : '—',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: textPrimary),
              textAlign: TextAlign.end,
            ),
          ])),
        ]),
        if (p90 != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
            child: Text(
              '~${(p90 + 20).clamp(0, 100).round()}% chance of 90+ min delay',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _gold),
            ),
          ),
        ],
        if (delayReason != null && delayReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _gold.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 15, color: _gold),
              const SizedBox(width: 8),
              Expanded(child: Text(delayReason,
                  style: TextStyle(fontSize: 12.5, color: textPrimary, height: 1.4, fontWeight: FontWeight.w400))),
            ]),
          ),
        ],
      ]),
    );
  }
}
