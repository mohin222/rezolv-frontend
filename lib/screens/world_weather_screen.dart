import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/api_repository.dart';
import '../utils/error_messages.dart';

/// Live weather across the whole flight network — every station reachable
/// from our tracked origins, grouped by continent. Opened from a card on
/// Overview; can take up to ~20s on a cold server cache (150+ stations),
/// so this always shows a clear loading state rather than a blank screen.
class WorldWeatherScreen extends StatefulWidget {
  const WorldWeatherScreen({super.key});

  @override
  State<WorldWeatherScreen> createState() => _WorldWeatherScreenState();
}

class _WorldWeatherScreenState extends State<WorldWeatherScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);
  static const _red = Color(0xFFC62828);

  bool _loading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _continents = {};
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedContinent;

  static const _continentOrder = ['Asia', 'Europe', 'America', 'Africa', 'Australia'];
  static const _continentIcons = {
    'Asia': Icons.public_rounded,
    'Europe': Icons.account_balance_rounded,
    'America': Icons.landscape_rounded,
    'Africa': Icons.terrain_rounded,
    'Australia': Icons.waves_rounded,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiRepository().fetchWorldWeather();
      setState(() {
        _continents = data ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  IconData _conditionIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunderstorm')) return Icons.bolt_rounded;
    if (c.contains('rain') || c.contains('drizzle')) return Icons.water_drop_rounded;
    if (c.contains('snow')) return Icons.ac_unit_rounded;
    if (c.contains('fog') || c.contains('mist') || c.contains('haze') || c.contains('smoke')) {
      return Icons.cloud_rounded;
    }
    return Icons.wb_sunny_rounded;
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'VFR': return const Color(0xFF2E7D32);
      case 'MVFR': return _gold;
      case 'IFR': return const Color(0xFFEF6C00);
      case 'LIFR': return _red;
      default: return Colors.grey;
    }
  }

  Map<String, List<Map<String, dynamic>>> get _filteredContinents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _continents;

    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in _continents.entries) {
      final matches = entry.value.where((station) {
        final code = (station['station'] as String? ?? '').toLowerCase();
        final city = (station['city'] as String? ?? '').toLowerCase();
        final airportName = (station['airport_name'] as String? ?? '').toLowerCase();
        return code.contains(query) || city.contains(query) || airportName.contains(query);
      }).toList();
      if (matches.isNotEmpty) result[entry.key] = matches;
    }
    return result;
  }

  List<String> get _orderedContinents {
    final keys = _filteredContinents.keys.toList();
    keys.sort((a, b) {
      final ai = _continentOrder.indexOf(a);
      final bi = _continentOrder.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return keys;
  }

  /// Continents actually visible after the continent-picker filter is
  /// applied on top of search — "All Continents" shows everything.
  List<String> get _visibleContinents {
    if (_selectedContinent == null) return _orderedContinents;
    return _orderedContinents.where((c) => c == _selectedContinent).toList();
  }

  static const _riskOrder = {'LIFR': 0, 'IFR': 1};

  /// Every station (across the whole network, ignoring the continent
  /// picker but respecting search) currently rated Poor or Very Poor
  /// visibility — worst first, so the stations that actually matter for
  /// flight risk aren't buried in a 100+ card scroll.
  List<Map<String, dynamic>> get _riskStations {
    final all = <Map<String, dynamic>>[];
    for (final stations in _filteredContinents.values) {
      for (final s in stations) {
        final category = ((s['current'] as Map?)?['flight_category']) as String?;
        if (_riskOrder.containsKey(category)) all.add(s);
      }
    }
    all.sort((a, b) {
      final ca = ((a['current'] as Map?)?['flight_category']) as String?;
      final cb = ((b['current'] as Map?)?['flight_category']) as String?;
      return (_riskOrder[ca] ?? 9).compareTo(_riskOrder[cb] ?? 9);
    });
    return all;
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

    final totalStations = _continents.values.fold<int>(0, (sum, list) => sum + list.length);

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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Weather', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  if (!_loading && _error == null)
                    Text('$totalStations stations · every airport in your flight network',
                        style: TextStyle(fontSize: 11, color: textSecondary)),
                ]),
              ),
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
                  Text('Loading weather for every station…\nfirst load can take up to 20 seconds',
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
          else if (_continents.isEmpty)
              Expanded(child: Center(child: Text('No weather data available right now', style: TextStyle(fontSize: 13, color: textSecondary))))
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 13.5, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search station, city or airport',
                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: textSecondary),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                            onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; }),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GestureDetector(
                  onTap: () => _pickContinent(context, cardBg, textPrimary, textSecondary, borderColor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                    child: Row(children: [
                      Icon(Icons.public_rounded, size: 16, color: textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_selectedContinent ?? 'All continents',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textSecondary),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: _filteredContinents.isEmpty
                    ? Center(child: Text('No stations match "$_query"', style: TextStyle(fontSize: 13, color: textSecondary)))
                    : RefreshIndicator(
                  color: _navy,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (_riskStations.isNotEmpty) ...[
                        _riskHeader(_riskStations.length, textPrimary, textSecondary),
                        const SizedBox(height: 10),
                        _riskStrip(_riskStations, cardBg, borderColor, textPrimary, textSecondary),
                        const SizedBox(height: 22),
                      ],
                      for (final continent in _visibleContinents) ...[
                        _continentHeader(continent, _filteredContinents[continent]!.length, textPrimary, textSecondary),
                        const SizedBox(height: 10),
                        _continentGrid(_filteredContinents[continent]!, cardBg, borderColor, textPrimary, textSecondary),
                        const SizedBox(height: 22),
                      ],
                    ],
                  ),
                ),
              ),
            ],
        ]),
      ),
    );
  }

  void _pickContinent(BuildContext context, Color cardBg, Color textPrimary, Color textSecondary, Color borderColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Browse by continent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 12),
            _continentOption(ctx, null, 'All continents', _continents.values.fold<int>(0, (sum, l) => sum + l.length), textPrimary, textSecondary),
            for (final c in _orderedContinents)
              _continentOption(ctx, c, c, _continents[c]?.length ?? 0, textPrimary, textSecondary),
          ]),
        ),
      ),
    );
  }

  Widget _continentOption(BuildContext ctx, String? value, String label, int count, Color textPrimary, Color textSecondary) {
    final selected = _selectedContinent == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(value == null ? Icons.public_rounded : (_continentIcons[value] ?? Icons.public_rounded),
          size: 20, color: selected ? _navy : textSecondary),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: textPrimary)),
      trailing: Text('$count', style: TextStyle(fontSize: 12, color: textSecondary)),
      onTap: () {
        setState(() => _selectedContinent = value);
        Navigator.pop(ctx);
      },
    );
  }

  Widget _riskHeader(int count, Color textPrimary, Color textSecondary) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
        child: const Center(child: Icon(Icons.visibility_off_rounded, size: 15, color: _red)),
      ),
      const SizedBox(width: 10),
      Text('Risk Weather', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: _red.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _red)),
      ),
    ]);
  }

  Widget _riskStrip(List<Map<String, dynamic>> stations, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _riskCard(stations[i], cardBg, borderColor, textPrimary, textSecondary),
      ),
    );
  }

  Widget _riskCard(Map<String, dynamic> weather, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final current = (weather['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final station = weather['station'] as String? ?? '—';
    final city = weather['city'] as String?;
    final tempC = current['temp_c'];
    final condition = (current['condition'] as String?) ?? '';
    final category = current['flight_category'] as String?;
    final categoryLabel = current['flight_category_label'] as String?;
    final color = _categoryColor(category);

    return GestureDetector(
      onTap: () => _showStationDetail(context, weather, cardBg, textPrimary, textSecondary, borderColor),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(station, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(width: 4),
            Expanded(child: Text(city ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: textSecondary))),
          ]),
          const Spacer(),
          Text(tempC != null ? '$tempC° · $condition' : condition,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: textSecondary)),
          const SizedBox(height: 6),
          if (categoryLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(categoryLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
            ),
        ]),
      ),
    );
  }

  Widget _continentHeader(String continent, int count, Color textPrimary, Color textSecondary) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: _navy.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
        child: Center(child: Icon(_continentIcons[continent] ?? Icons.public_rounded, size: 15, color: _navy)),
      ),
      const SizedBox(width: 10),
      Text(continent, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _gold)),
      ),
    ]);
  }

  Widget _continentGrid(List<Map<String, dynamic>> stations, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: stations.length,
      itemBuilder: (context, i) => _stationCard(stations[i], cardBg, borderColor, textPrimary, textSecondary),
    );
  }

  Widget _stationCard(Map<String, dynamic> weather, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final current = (weather['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final station = weather['station'] as String? ?? '—';
    final city = weather['city'] as String?;
    final tempC = current['temp_c'];
    final condition = (current['condition'] as String?) ?? 'Clear';
    final category = current['flight_category'] as String?;
    final categoryLabel = current['flight_category_label'] as String?;

    return GestureDetector(
      onTap: () => _showStationDetail(context, weather, cardBg, textPrimary, textSecondary, borderColor),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(station, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                if (city != null)
                  Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: textSecondary)),
              ]),
            ),
            Icon(_conditionIcon(condition), size: 16, color: _navy),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(tempC != null ? '$tempC°' : '—',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(width: 6),
            Expanded(child: Text(condition, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: textSecondary))),
          ]),
          if (categoryLabel != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _categoryColor(category).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(categoryLabel, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: _categoryColor(category))),
            ),
          ],
        ]),
      ),
    );
  }

  void _showStationDetail(BuildContext context, Map<String, dynamic> weather, Color cardBg, Color textPrimary, Color textSecondary, Color borderColor) {
    final current = (weather['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final station = weather['station'] as String? ?? '—';
    final city = weather['city'] as String?;
    final airportName = weather['airport_name'] as String?;
    final next10h = (weather['next_10h'] as Map?)?.cast<String, dynamic>();
    final periods = (next10h?['periods'] as List?)?.cast<Map>().map((e) => e.cast<String, dynamic>()).toList() ?? [];
    final windowStart = next10h?['window_start'] as String?;
    final windowEnd = next10h?['window_end'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).viewPadding.bottom),
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('$station — ${city ?? ''}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
            if (airportName != null) Text(airportName, style: TextStyle(fontSize: 11.5, color: textSecondary)),
            const SizedBox(height: 14),
            Row(children: [
              Text('${current['temp_c'] ?? '—'}°C', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(width: 10),
              Text(current['condition'] ?? '', style: TextStyle(fontSize: 14, color: textSecondary)),
            ]),
            const SizedBox(height: 6),
            Text(
              [
                if (current['wind'] != null) 'Wind ${current['wind']}',
                if (current['visibility_mi'] != null) 'Vis ${current['visibility_mi']}mi',
                if (current['sky'] != null) current['sky'],
              ].join('  •  '),
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: borderColor),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 14, color: _gold),
              const SizedBox(width: 6),
              Text('NEXT 10 HOURS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.6)),
            ]),
            if (windowStart != null && windowEnd != null) ...[
              const SizedBox(height: 3),
              Text('$windowStart → $windowEnd (station local time)',
                  style: TextStyle(fontSize: 11, color: textSecondary)),
            ],
            const SizedBox(height: 10),
            if (periods.isEmpty)
              Text('No significant weather expected in the next 10 hours.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4))
            else
              for (final p in periods) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 78,
                    child: Text(p['time'] as String? ?? '—',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _gold)),
                  ),
                  Expanded(
                    child: Text(p['description'] as String? ?? '',
                        style: TextStyle(fontSize: 12.5, color: textPrimary, height: 1.3)),
                  ),
                ]),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}
