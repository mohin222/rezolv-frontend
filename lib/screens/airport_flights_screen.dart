import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/api_repository.dart';
import '../utils/error_messages.dart';

/// Search any airport code worldwide (not just our tracked stations) and
/// see today's moderate-and-higher-risk flights there — both departures
/// and arrivals, each with its plain-English delay reason. Lumo's API
/// answers for any airport; this just calls it directly for whatever code
/// the user types.
class AirportFlightsScreen extends StatefulWidget {
  const AirportFlightsScreen({super.key});

  @override
  State<AirportFlightsScreen> createState() => _AirportFlightsScreenState();
}

class _AirportFlightsScreenState extends State<AirportFlightsScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);
  static const _red = Color(0xFFC62828);
  static const _green = Color(0xFF2E7D32);

  static final _timeFmt = DateFormat('h:mm a');

  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;
  final Set<String> _expandedKeys = {};

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  DateTime? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw.trim().replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _search() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final data = await ApiRepository().fetchAirportFlights(code);
      if (!mounted) return;
      if (data == null || data['unavailable'] == true) {
        setState(() { _loading = false; _error = 'No data for "$code" — check the airport code is correct.'; });
        return;
      }
      setState(() { _result = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyError(e); });
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'HIGH':
      case 'SEVERE':
        return _red;
      case 'MODERATE':
        return _gold;
      default:
        return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);

    final departures = ((_result?['departures'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final arrivals = ((_result?['arrivals'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final code = _result?['code'] as String?;
    final city = _result?['city'] as String?;
    final name = _result?['name'] as String?;

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
              Expanded(
                child: Text('Search Any Airport', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(fontSize: 14, color: textPrimary, fontWeight: FontWeight.w600),
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Airport code, e.g. HBX',
                    hintStyle: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w400),
                    prefixIcon: Icon(Icons.flight_takeoff_rounded, size: 19, color: textSecondary),
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _navy)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _loading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _navy))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textSecondary)),
                        ),
                      )
                    : _result == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.search_rounded, size: 40, color: textSecondary),
                                const SizedBox(height: 10),
                                Text('Type any airport code to see today\'s\nmoderate and high risk flights there',
                                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: textSecondary)),
                              ]),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    colors: [Color(0xFF0D2B4E), Color(0xFF15477F)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(code ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text([if (name != null) name, if (city != null) city].join(' · '),
                                      style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    _countChip('${departures.length}', 'At-Risk Departures'),
                                    const SizedBox(width: 10),
                                    _countChip('${arrivals.length}', 'At-Risk Arrivals'),
                                  ]),
                                ]),
                              ),
                              const SizedBox(height: 20),
                              _sectionHeader('AT-RISK DEPARTURES', Icons.flight_takeoff_rounded, textPrimary),
                              const SizedBox(height: 10),
                              if (departures.isEmpty)
                                _emptyRow('No moderate or high risk departures today', cardBg, borderColor, textSecondary)
                              else
                                ...departures.map((f) => _flightRow(f, isDeparture: true, cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)),
                              const SizedBox(height: 22),
                              _sectionHeader('AT-RISK ARRIVALS', Icons.flight_land_rounded, textPrimary),
                              const SizedBox(height: 10),
                              if (arrivals.isEmpty)
                                _emptyRow('No moderate or high risk arrivals today', cardBg, borderColor, textSecondary)
                              else
                                ...arrivals.map((f) => _flightRow(f, isDeparture: false, cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)),
                            ],
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _countChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color textPrimary) {
    return Row(children: [
      Icon(icon, size: 16, color: textPrimary),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: 0.5)),
    ]);
  }

  Widget _emptyRow(String text, Color cardBg, Color borderColor, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: textSecondary)),
    );
  }

  Widget _flightRow(Map<String, dynamic> f, {required bool isDeparture, required Color cardBg, required Color borderColor, required Color textPrimary, required Color textSecondary}) {
    final flightNumber = (f['flight_number'] as String?)?.trim();
    final airlineName = f['airline_name'] as String?;
    final otherCode = isDeparture ? f['destination'] as String? : f['origin'] as String?;
    final otherCity = isDeparture ? f['destination_city'] as String? : f['origin_city'] as String?;
    final time = _parse(isDeparture ? f['departure_time'] as String? : f['arrival_time'] as String?);
    final risk = f['risk'] as String?;
    final delayReason = f['delay_reason'] as String?;
    final hasReason = delayReason != null && delayReason.isNotEmpty;
    final key = '${isDeparture ? 'D' : 'A'}_${flightNumber}_${time?.toIso8601String()}';
    final expanded = _expandedKeys.contains(key);

    return GestureDetector(
      onTap: hasReason
          ? () => setState(() {
                if (expanded) {
                  _expandedKeys.remove(key);
                } else {
                  _expandedKeys.add(key);
                }
              })
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 62,
              child: Text(time != null ? _timeFmt.format(time) : '—',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
            ),
            Container(width: 1, height: 28, color: borderColor, margin: const EdgeInsets.symmetric(horizontal: 10)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(flightNumber ?? '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                  if (airlineName != null) ...[
                    const SizedBox(width: 6),
                    Expanded(child: Text(airlineName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: textSecondary))),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  isDeparture ? 'to $otherCode${otherCity != null ? ' · $otherCity' : ''}' : 'from $otherCode${otherCity != null ? ' · $otherCity' : ''}',
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ]),
            ),
            if (risk != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _riskColor(risk).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(risk, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _riskColor(risk))),
              ),
            ],
            if (hasReason) ...[
              const SizedBox(width: 4),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: textSecondary),
            ],
          ]),
          if (expanded && hasReason) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: _riskColor(risk).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 14, color: _riskColor(risk)),
                const SizedBox(width: 7),
                Expanded(child: Text(delayReason,
                    style: TextStyle(fontSize: 11.5, color: textPrimary, height: 1.35, fontWeight: FontWeight.w400))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
