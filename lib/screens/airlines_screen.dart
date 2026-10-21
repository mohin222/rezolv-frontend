import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/api_repository.dart';
import '../utils/error_messages.dart';
import 'airline_flight_risk_screen.dart';

class AirlinesScreen extends StatefulWidget {
  const AirlinesScreen({super.key});

  @override
  State<AirlinesScreen> createState() => _AirlinesScreenState();
}

class _AirlinesScreenState extends State<AirlinesScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _airlines = [];
  final _filterCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final airlines = await ApiRepository().fetchTrackedAirlines();
      setState(() { _airlines = airlines; _loading = false; });
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

    final query = _filter.trim().toLowerCase();
    final visibleAirlines = query.isEmpty
        ? _airlines
        : _airlines.where((a) {
            final code = ((a['code'] as String?) ?? '').toLowerCase();
            final name = ((a['name'] as String?) ?? '').toLowerCase();
            return code.contains(query) || name.contains(query);
          }).toList();

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
              Expanded(child: Text('Airlines at Risk', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary))),
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary, size: 20),
                onPressed: _loading ? null : _load,
              ),
            ]),
          ),
          if (!_loading && _error == null && _airlines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _filterCtrl,
                onChanged: (v) => setState(() => _filter = v),
                style: TextStyle(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Filter by airline name or code',
                  hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, size: 19, color: textSecondary),
                  suffixIcon: _filter.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                          onPressed: () => setState(() { _filterCtrl.clear(); _filter = ''; }),
                        ),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _navy)),
                ),
              ),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _navy)))
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
          else if (_airlines.isEmpty)
            Expanded(child: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No airlines being tracked yet — add one from the backend admin.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textSecondary)),
            )))
          else if (visibleAirlines.isEmpty)
            Expanded(child: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No airline matches "$_filter".',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: textSecondary)),
            )))
          else
            Expanded(
              child: RefreshIndicator(
                color: _navy,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text('Tap an airline to see every station it flies from and which of its flights are at risk right now.',
                        style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4)),
                    const SizedBox(height: 14),
                    for (final a in visibleAirlines) ...[
                      _airlineTile(a, cardBg, borderColor, textPrimary, textSecondary),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _airlineTile(Map<String, dynamic> airline, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final code = (airline['code'] as String?) ?? '';
    final name = (airline['name'] as String?)?.trim();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AirlineFlightRiskScreen(airlineCode: code, airlineName: name ?? code)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _gold))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text((name == null || name.isEmpty) ? code : name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary))),
          Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
        ]),
      ),
    );
  }
}
