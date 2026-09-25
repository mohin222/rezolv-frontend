import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/api_repository.dart';
import '../utils/error_messages.dart';

/// AI / AIX booking numbers, shown in place of the RICH inventory view when
/// the Dashboard toggle is on AI or AIX. Every value comes straight from the
/// backend, which applies the same rules as the ops dashboard (check-in date,
/// IST days, tracked stations, deleted rooms excluded). The station filter,
/// date filter and hotel list all use the same backend calculation.
class BookingsPanel extends StatefulWidget {
  /// 'AI' or 'IX'
  final String airline;
  const BookingsPanel({super.key, required this.airline});

  @override
  State<BookingsPanel> createState() => BookingsPanelState();
}

class BookingsPanelState extends State<BookingsPanel> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);
  static const _hotelsPageSize = 10;

  static const _periods = [
    ('today', 'Today'),
    ('yesterday', 'Yesterday'),
    ('week', '7 Days'),
    ('month', 'MTD'),
  ];
  static const _periodFull = {
    'today': 'Today',
    'yesterday': 'Yesterday',
    'week': 'Last 7 days',
    'month': 'Month to date',
  };

  static final NumberFormat _n = NumberFormat.decimalPattern('en_IN');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat _shortFmt = DateFormat('d MMM');
  static final DateFormat _longFmt = DateFormat('d MMM yyyy');

  String _period = 'today';
  String? _station; // null = all stations
  DateTimeRange? _range; // null = the live Today / Yesterday / 7 Days / MTD view
  List<String> _stations = [];
  int _hotelsShown = _hotelsPageSize;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  Timer? _timer;

  String get _periodKey => _range != null ? 'range' : _period;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStations();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStations() async {
    try {
      final codes = await ApiRepository().fetchAirportCodes();
      if (!mounted) return;
      setState(() => _stations = codes.map((c) => '${c['code']}').where((c) => c.isNotEmpty).toList());
    } catch (_) {
      // the station filter just stays empty — the panel itself still works
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiRepository().fetchBookings(
        widget.airline,
        station: _station,
        from: _range == null ? null : _apiFmt.format(_range!.start),
        to: _range == null ? null : _apiFmt.format(_range!.end),
      );
      if (!mounted) return;
      setState(() { _data = data; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _loading = false;
        _data = null;
        _error = e is BookingsException ? e.message : friendlyError(e);
      });
    }
  }

  /// Back to the defaults (all stations, no date range, Today) and reload —
  /// what pull-to-refresh and the top reload button do.
  Future<void> resetAndReload() async {
    setState(() {
      _period = 'today';
      _station = null;
      _range = null;
      _hotelsShown = _hotelsPageSize;
      _data = null;
    });
    await _load();
  }

  void _applyFilters() {
    setState(() { _data = null; _hotelsShown = _hotelsPageSize; });
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now.add(const Duration(days: 60)),
      initialDateRange: _range,
      helpText: 'Filter by check-in date',
    );
    if (picked == null || !mounted) return;
    _range = picked;
    _applyFilters();
  }

  void _clearRange() {
    _range = null;
    _applyFilters();
  }

  void _pickStation(String? code) {
    if (code == _station) return;
    _station = code;
    _applyFilters();
  }

  void _openStationSheet(Color cardBg, Color textPrimary, Color textSecondary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select Station', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
          ),
          ListTile(
            leading: const Icon(Icons.public, size: 18, color: _navy),
            title: Text('All Stations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
            trailing: _station == null ? const Icon(Icons.check, color: _navy, size: 18) : null,
            onTap: () { Navigator.pop(ctx); _pickStation(null); },
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(shrinkWrap: true, children: _stations.map((code) => ListTile(
              leading: Icon(Icons.flight_takeoff, size: 18, color: textSecondary),
              title: Text(code, style: TextStyle(fontSize: 14, fontWeight: _station == code ? FontWeight.w700 : FontWeight.w400, color: textPrimary)),
              trailing: _station == code ? const Icon(Icons.check, color: _navy, size: 18) : null,
              onTap: () { Navigator.pop(ctx); _pickStation(code); },
            )).toList()),
          ),
        ]),
      ),
    );
  }

  String _num(dynamic v) => v == null ? '—' : _n.format((v as num).toInt());

  String get _rangeLabel {
    final r = _range!;
    return r.start.year == r.end.year
        ? '${_shortFmt.format(r.start)} – ${_longFmt.format(r.end)}'
        : '${_longFmt.format(r.start)} – ${_longFmt.format(r.end)}';
  }

  String get _scopeLabel => _range != null ? _rangeLabel : (_periodFull[_period] ?? '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);
    final airlineName = widget.airline == 'IX' ? 'Air India Express' : 'Air India';

    final periods = (_data?['periods'] as Map?)?.cast<String, dynamic>();
    final p = (periods?[_periodKey] as Map?)?.cast<String, dynamic>();
    final hotelsByPeriod = (_data?['hotels'] as Map?)?.cast<String, dynamic>();
    final hotels = ((hotelsByPeriod?[_periodKey] as List?) ?? const []).cast<Map<String, dynamic>>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _filters(cardBg, borderColor, textPrimary, textSecondary),
      const SizedBox(height: 12),
      Text('Bookings · LIVE ($airlineName)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
      const SizedBox(height: 10),
      if (_range == null) ...[
        Row(children: _periods.map((x) {
          final selected = x.$1 == _period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _period = x.$1; _hotelsShown = _hotelsPageSize; }),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _navy : cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: selected ? null : Border.all(color: borderColor),
                ),
                child: Text(x.$2, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : textSecondary)),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 16),
      ],
      if (_loading && _data == null)
        const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator(color: _navy)))
      else if (_error != null && _data == null)
        _message(Icons.cloud_off_rounded, _error!, textSecondary, cardBg, borderColor)
      else if (p == null)
        _message(Icons.info_outline, 'No booking data yet', textSecondary, cardBg, borderColor)
      else ...[
        _headline(p, airlineName),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _small('Bookings (by room)', _num(p['bookings_by_room']), cardBg, borderColor, textPrimary, textSecondary,
              info: 'Hotel rooms only. Each room counts once — 3 passengers sharing one room = 1 booking here.'),
          _small('Pending', _num(p['pending']), cardBg, borderColor, textPrimary, textSecondary,
              valueColor: (p['pending'] as num? ?? 0) > 0 ? const Color(0xFFC62828) : null),
          _small('Rejected', _num(p['rejected']), cardBg, borderColor, textPrimary, textSecondary),
          _small('Room nights', _num(p['room_nights']), cardBg, borderColor, textPrimary, textSecondary,
              info: 'Rooms × nights. Each hotel room counts once per night it is booked.'),
          _small('Pax nights', _num(p['pax_nights']), cardBg, borderColor, textPrimary, textSecondary,
              info: 'Passengers × nights: every passenger with a hotel room counts once for each night they stay.'),
        ]),
        const SizedBox(height: 22),
        _hotelsSection(hotels, cardBg, borderColor, textPrimary, textSecondary),
        const SizedBox(height: 10),
        Text(_footer(), style: TextStyle(fontSize: 10.5, color: textSecondary)),
      ],
    ]);
  }

  String _footer() {
    final today = _data?['today'] as String?;
    return 'By check-in date · IST${today != null ? ' · as of $today' : ''}';
  }

  Widget _filters(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    Widget box({required IconData icon, required String text, required bool active, required VoidCallback onTap, VoidCallback? onClear}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? _navy : borderColor, width: active ? 1.4 : 1),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: active ? _navy : textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(text, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? textPrimary : textSecondary))),
            if (onClear != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.close, size: 16, color: textSecondary)),
              )
            else
              Icon(Icons.keyboard_arrow_down, size: 18, color: textSecondary),
          ]),
        ),
      );
    }

    return Row(children: [
      Expanded(child: box(
        icon: Icons.flight_takeoff,
        text: _station ?? 'All Stations',
        active: _station != null,
        onTap: () => _openStationSheet(cardBg, textPrimary, textSecondary),
      )),
      const SizedBox(width: 8),
      Expanded(child: box(
        icon: Icons.calendar_month_rounded,
        text: _range == null ? 'Date filter' : _rangeLabel,
        active: _range != null,
        onTap: _pickRange,
        onClear: _range == null ? null : _clearRange,
      )),
    ]);
  }

  Widget _hotelsSection(List<Map<String, dynamic>> hotels, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final shown = hotels.take(_hotelsShown).toList();
    final remaining = hotels.length - shown.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget headCell(String t, {TextAlign align = TextAlign.center}) =>
        Text(t, textAlign: align, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.4));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Hotels used · $_scopeLabel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Text('${hotels.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _gold)),
        ),
      ]),
      const SizedBox(height: 10),
      if (hotels.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
          child: Text('No hotels used', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: textSecondary)),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(children: [
                SizedBox(width: 34, child: headCell('STAR')),
                Expanded(child: headCell('HOTEL · STN', align: TextAlign.left)),
                SizedBox(width: 62, child: headCell('BOOKINGS')),
                SizedBox(width: 62, child: headCell('DAYS USED')),
              ]),
            ),
            for (final h in shown) ...[
              Divider(height: 1, color: borderColor),
              _hotelRow(h, textPrimary, textSecondary),
            ],
          ]),
        ),
      if (remaining > 0)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(
            child: TextButton(
              onPressed: () => setState(() => _hotelsShown += _hotelsPageSize),
              child: Text('Load ${remaining < _hotelsPageSize ? remaining : _hotelsPageSize} more ($remaining left)',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _gold)),
            ),
          ),
        ),
    ]);
  }

  Widget _hotelRow(Map<String, dynamic> h, Color textPrimary, Color textSecondary) {
    final rating = '${h['rating'] ?? ''}';
    final star = RegExp(r'\d').firstMatch(rating)?.group(0);
    final daysUsed = h['days_used'] ?? 0;
    final periodDays = h['period_days'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: star == null
              ? Text('—', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.star_rounded, size: 13, color: _gold),
                  Text(star, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                ]),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${h['name']}', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
          if (h['station'] != null) Text('${h['station']}', style: TextStyle(fontSize: 10.5, color: textSecondary)),
        ])),
        SizedBox(
          width: 62,
          child: Text(_num(h['bookings']), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary)),
        ),
        SizedBox(
          width: 62,
          child: Text('$daysUsed/${periodDays ?? '—'}', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: textSecondary)),
        ),
      ]),
    );
  }

  Widget _headline(Map<String, dynamic> p, String airlineName) {
    final occ = (p['occupancy'] as Map?)?.cast<String, dynamic>() ?? {};
    const labels = [['SINGLE', 'Single'], ['DOUBLE', 'Double'], ['TRIPLE', 'Triple'], ['QUAD', 'Quad']];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B4E), Color(0xFF15477F)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bookings · $_scopeLabel${_station != null ? ' · $_station' : ''} · $airlineName',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(_num(p['bookings']), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
          ])),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 20),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: labels.map((l) => Expanded(
          child: Column(children: [
            Text(_num(occ[l[0]] ?? 0), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(l[1], style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
          ]),
        )).toList()),
      ]),
    );
  }

  Widget _small(String label, String value, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary,
      {String? info, Color? valueColor}) {
    final width = (MediaQuery.of(context).size.width - 32 - 8) / 2;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(label, style: TextStyle(fontSize: 11.5, color: textSecondary), overflow: TextOverflow.ellipsis)),
            if (info != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: info,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                child: Icon(Icons.info_outline, size: 13, color: textSecondary),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor ?? textPrimary)),
        ]),
      ),
    );
  }

  Widget _message(IconData icon, String text, Color textSecondary, Color cardBg, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(children: [
        Icon(icon, color: textSecondary, size: 34),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: textSecondary)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: _navy),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}
