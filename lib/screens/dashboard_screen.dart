import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/api_repository.dart';
import '../utils/app_version.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _navy = Color(0xFF0D2B4E);

  static const _periods = [
    ('today', 'Today'),
    ('week', 'This Week'),
    ('month', 'This Month'),
  ];

  String _selectedPeriod = 'today';
  String? _selectedStation; // null = all stations
  List<Map<String, dynamic>> _allStations = [];
  bool _loading = true;
  int _totalRooms = 0;
  List<Map<String, dynamic>> _starMix = [];
  List<Map<String, dynamic>> _topHotels = [];
  String _fromDate = '';
  String _toDate = '';
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _load();
    _loadStations();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStations() async {
    try {
      final codes = await ApiRepository().fetchAirportCodes();
      if (!mounted) return;
      setState(() => _allStations = codes);
    } catch (_) {
      // station picker just stays empty — dashboard itself still works
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await ApiRepository().fetchDashboardSummary(_selectedPeriod, station: _selectedStation);
      if (!mounted) return;
      setState(() {
        _totalRooms = (data['total_available_rooms'] as num?)?.toInt() ?? 0;
        _starMix = (data['star_mix'] as List? ?? []).cast<Map<String, dynamic>>();
        _topHotels = (data['top_hotels'] as List? ?? []).cast<Map<String, dynamic>>();
        _fromDate = data['from_date'] as String? ?? '';
        _toDate = data['to_date'] as String? ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent) return; // keep showing the last good numbers over a transient background failure
      setState(() {
        _totalRooms = 0;
        _starMix = [];
        _topHotels = [];
        _loading = false;
      });
    }
  }

  void _selectPeriod(String period) {
    if (period == _selectedPeriod) return;
    setState(() => _selectedPeriod = period);
    _load();
  }

  void _openStationPicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Select Station', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
            ),
            ListTile(
              leading: Icon(Icons.public, size: 18, color: _navy),
              title: Text('All Stations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              trailing: _selectedStation == null ? Icon(Icons.check, color: _navy, size: 18) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _selectedStation = null);
                _load();
              },
            ),
            Divider(height: 1, color: dividerColor),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: _allStations.map((s) {
                  final code = s['code'] as String? ?? '';
                  final city = s['city'] as String? ?? s['name'] as String? ?? '';
                  final isSel = _selectedStation == code;
                  return ListTile(
                    leading: Icon(Icons.flight_takeoff, size: 18, color: textSecondary),
                    title: Text('$code${city.isNotEmpty ? ' - $city' : ''}',
                        style: TextStyle(fontSize: 14, fontWeight: isSel ? FontWeight.w700 : FontWeight.w400, color: isSel ? _navy : textPrimary)),
                    trailing: isSel ? Icon(Icons.check, color: _navy, size: 18) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedStation = code);
                      _load();
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
          ]),
        );
      },
    );
  }

  static final _niceDateFmt = DateFormat('d MMM');

  String _formatDate(String iso) {
    try {
      return _niceDateFmt.format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String get _periodLabel =>
      _periods.firstWhere((p) => p.$1 == _selectedPeriod).$2;

  static const _lightBlue = Color(0xFF1565C0);
  static const _purple = Color(0xFF7B1FA2);

  Color _starColor(dynamic stars) {
    final s = stars is int ? stars : int.tryParse('$stars') ?? 0;
    return s.isOdd ? _lightBlue : _purple;
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _navy,
          onRefresh: _load,
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _header(textPrimary, textSecondary),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: _openStationPicker,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(children: [
                      Icon(Icons.flight_takeoff, size: 17, color: textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _selectedStation == null ? 'All Stations' : _selectedStation!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedStation == null ? FontWeight.w400 : FontWeight.w600,
                          color: _selectedStation == null ? textSecondary : textPrimary,
                        ),
                      )),
                      Icon(Icons.keyboard_arrow_down, size: 18, color: textSecondary),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Period · LIVE (RICH)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 10),
                Row(children: _periods.map((p) {
                  final isSelected = p.$1 == _selectedPeriod;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _selectPeriod(p.$1),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _navy : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected ? null : Border.all(color: borderColor),
                        ),
                        child: Text(p.$2, textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : textSecondary)),
                      ),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF0D2B4E), Color(0xFF15477F)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Total Available Rooms · $_periodLabel'
                        '${_selectedStation != null ? ' · $_selectedStation' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(_loading ? '…' : '$_totalRooms', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (_fromDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _fromDate == _toDate
                              ? _formatDate(_fromDate)
                              : '${_formatDate(_fromDate)}  –  ${_formatDate(_toDate)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ])),
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.hotel_rounded, color: Colors.white, size: 20),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),
                Text('Star Category Breakdown · $_periodLabel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 10),
                if (_starMix.isEmpty)
                  _breakdownCard(label: 'No live data yet', value: '0', cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)
                else
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _starMix.map((s) {
                      final stars = s['stars'];
                      final rooms = s['rooms'];
                      final color = _starColor(stars);
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 32 - 16) / 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [
                            Icon(Icons.star_rounded, color: color, size: 18),
                            const SizedBox(height: 4),
                            Text('$stars Star', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text('$rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 20),
                Text('Top Hotels by Available Rooms · $_periodLabel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 10),
                if (_topHotels.isEmpty)
                  _breakdownCard(label: 'No live data yet', value: '0', cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)
                else
                  ..._topHotels.map((h) {
                    final color = _starColor(h['star_category']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: IntrinsicHeight(
                        child: Row(children: [
                          Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${h['hotel_name']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Row(children: [
                                  Icon(Icons.star_rounded, size: 12, color: color),
                                  const SizedBox(width: 2),
                                  Text('${h['hotel_city']} · ${h['star_category'] ?? '—'} Star', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                                ]),
                              ])),
                              Text('${h['available_rooms']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                            ]),
                          )),
                        ]),
                      ),
                    );
                  }),
              ]),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _header(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(9)),
          child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rezolv', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          Text('Dashboard · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),
        ])),
        IconButton(
          icon: Icon(Icons.refresh, color: textPrimary, size: 20),
          onPressed: _load,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 6),
        Row(children: [
          Icon(Icons.circle, size: 7, color: _loading ? Colors.orange : Colors.green),
          const SizedBox(width: 5),
          Text(_loading ? 'Syncing' : 'Live', style: TextStyle(fontSize: 11, color: textPrimary)),
        ]),
      ]),
    );
  }

  Widget _breakdownCard({required String label, required String value, required Color cardBg, required Color borderColor, required Color textPrimary, required Color textSecondary}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
      ]),
    );
  }
}
