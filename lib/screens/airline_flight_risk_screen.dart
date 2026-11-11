import 'dart:async';
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
  static final DateFormat _timeFmt = DateFormat('HH:mm');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _stations = [];
  Map<String, String> _stationCities = {};
  DateTime? _computedAt;
  // Which day's flights the list shows — toggled by the Today / Tomorrow
  // buttons in the header.
  bool _showToday = true;
  // False for data saved before the backend sent today's flights.
  bool _hasToday = false;
  bool _pending = false;
  Timer? _pendingPollTimer;
  static const _pendingPollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pendingPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
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
      // At-risk flights only, earliest departure first.
      List<Map<String, dynamic>> risky(dynamic list) =>
          ((list as List? ?? []).cast<Map<String, dynamic>>()).where(_meetsRiskThreshold).toList()
            ..sort((a, b) => _departureKey(a).compareTo(_departureKey(b)));
      for (final st in rawStations) {
        final today = risky(st['today']).where((f) => !_hasDeparted(f)).toList();
        final tomorrow = risky(st['tomorrow'] ?? st['week']);
        if (today.isEmpty && tomorrow.isEmpty) continue;
        filteredStations.add({...st, 'today': today, 'tomorrow': tomorrow});
      }
      final hasToday = data['today_date'] != null;
      final stillPending = data['pending'] == true;
      setState(() {
        _stationCities = cities;
        _stations = filteredStations;
        _hasToday = hasToday;
        if (!hasToday) _showToday = false;
        _computedAt = computedAtRaw != null ? DateTime.tryParse(computedAtRaw)?.toLocal() : null;
        // Lumo couldn't be reached (or today's call budget is used up) —
        // say so instead of showing an empty 'nothing at risk' list.
        _pending = stillPending || data['unavailable'] == true;
        _loading = false;
      });
      // The backend's first-time network check can take a while — poll
      // quietly in the background instead of making someone manually
      // pull-to-refresh every so often to see if it's finished yet.
      _pendingPollTimer?.cancel();
      if (stillPending) {
        _pendingPollTimer = Timer(_pendingPollInterval, () {
          if (mounted) _load(silent: true);
        });
      }
    } catch (e) {
      if (!silent) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  // Sort key for a flight's departure: UTC when the backend sends it (right
  // across time zones), else the local departure time.
  static String _departureKey(Map<String, dynamic> flight) =>
      (flight['departure_utc'] as String?) ?? (flight['departure_time'] as String?) ?? '';

  // Today's flight already left? The backend hides these too; this keeps
  // the list right while the screen stays open. departure_utc is Lumo's
  // estimated (else scheduled) departure, in UTC.
  static bool _hasDeparted(Map<String, dynamic> flight) {
    final raw = flight['departure_utc'] as String?;
    if (raw == null || raw.isEmpty) return false;
    final departs = DateTime.tryParse(raw.endsWith('Z') ? raw : '${raw}Z');
    return departs != null && !departs.isAfter(DateTime.now().toUtc());
  }

  String get _dayKey => _showToday ? 'today' : 'tomorrow';
  int _countFor(String day) => _stations.fold<int>(0, (s, st) => s + ((st[day] as List?)?.length ?? 0));
  List<Map<String, dynamic>> get _shownStations =>
      _stations.where((st) => ((st[_dayKey] as List?) ?? []).isNotEmpty).toList();

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
                    if (!_pending && _shownStations.isNotEmpty) ...[
                      Text(
                        "${_showToday ? "TODAY'S" : "TOMORROW'S"} AT-RISK FLIGHTS · ${_countFor(_dayKey)} across ${_shownStations.length} ${_shownStations.length == 1 ? 'station' : 'stations'}",
                        style: TextStyle(fontSize: 10.5, color: textSecondary, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_pending)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Center(child: Text('Couldn\'t check ${widget.airlineName} right now — please try again in a little while.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textSecondary))),
                      )
                    else if (_shownStations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Center(child: Text(
                            _showToday && !_hasToday
                                ? "Today's flights will show after the next update."
                                : 'No at-risk flights for ${widget.airlineName} ${_showToday ? 'today' : 'tomorrow'}.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textSecondary))),
                      )
                    else
                      for (final st in _shownStations) ...[
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
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('AT RISK NOW', style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            Text(_timeFmt.format(DateTime.now()), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dayButton('Today', true)),
          const SizedBox(width: 10),
          Expanded(child: _dayButton('Tomorrow', false)),
        ]),
        if (_computedAt != null) ...[
          const SizedBox(height: 10),
          Text('Updated ${_dateFmt.format(_computedAt!)}, ${_timeFmt.format(_computedAt!)}',
              style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ]),
    );
  }

  /// Today / Tomorrow switch: shows that day's at-risk flight count and,
  /// when tapped, lists that day's flights below.
  Widget _dayButton(String label, bool today) {
    final selected = _showToday == today;
    final available = !today || _hasToday;
    final count = _pending || !available ? '—' : '${_countFor(today ? 'today' : 'tomorrow')}';
    return GestureDetector(
      onTap: available ? () => setState(() => _showToday = today) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(selected ? 1 : 0.18)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? _navy : Colors.white)),
            Text('at-risk flights', style: TextStyle(fontSize: 9.5, color: selected ? _navy.withOpacity(0.6) : Colors.white54)),
          ])),
          Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: selected ? _navy : Colors.white)),
        ]),
      ),
    );
  }

  Widget _stationSection(Map<String, dynamic> station, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final code = (station['station'] as String?) ?? '';
    final city = _stationCities[code] ?? '';
    final flights = (station[_dayKey] as List? ?? []).cast<Map<String, dynamic>>();
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
