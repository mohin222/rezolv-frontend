import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/api_repository.dart';
import '../models/real_hotel_days.dart';

class SoldOutCalendarScreen extends StatefulWidget {
  final String stationCode;
  final String stationCity;

  const SoldOutCalendarScreen({
    super.key,
    required this.stationCode,
    required this.stationCity,
  });

  @override
  State<SoldOutCalendarScreen> createState() => _SoldOutCalendarScreenState();
}

class _SoldOutCalendarScreenState extends State<SoldOutCalendarScreen> {
  static const _navy    = Color(0xFF0D2B4E);
  static const _gold    = Color(0xFFC1791C);
  static const _darkRed = Color(0xFFC62828);
  static const _green   = Color(0xFF1B7A3D);

  static final DateFormat _apiDateFmt   = DateFormat('yyyy-MM-dd');
  static final DateFormat _monthFmt     = DateFormat('MMMM yyyy');
  static final DateFormat _dayHeaderFmt = DateFormat('EEEE, d MMMM yyyy');

  late DateTime _month; // first day of the visible month
  late final DateTime _today;

  bool _loading = true;
  String? _error;
  List<RealHotelDays> _hotels = [];

  late final DateTime _minMonth;
  late final DateTime _maxMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
    _minMonth = DateTime(now.year - 1, now.month);
    _maxMonth = DateTime(now.year + 1, now.month);
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() { _loading = true; _error = null; });
    try {
      final firstDay = DateTime(_month.year, _month.month, 1);
      final lastDay  = DateTime(_month.year, _month.month + 1, 0);
      final (_, hotels) = await ApiRepository().fetchStationDays(
        widget.stationCode,
        fromDate: _apiDateFmt.format(firstDay),
        toDate: _apiDateFmt.format(lastDay),
      );
      if (!mounted) return;
      setState(() { _hotels = hotels; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() => _month = next);
    _loadMonth();
  }

  bool _hasDataOn(String dateStr) => _hotels.any((h) => h.roomsFor(dateStr) != null);
  List<RealHotelDays> _soldOutOn(String dateStr) =>
      _hotels.where((h) => h.roomsFor(dateStr) == 0).toList();

  /// Days in the visible month, restricted to days we have data for.
  List<DateTime> get _daysWithData {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final out = <DateTime>[];
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      if (_hasDataOn(_apiDateFmt.format(date))) out.add(date);
    }
    return out;
  }

  int get _soldOutDaysCount =>
      _daysWithData.where((d) => _soldOutOn(_apiDateFmt.format(d)).isNotEmpty).length;

  int get _clearDaysCount => _daysWithData.length - _soldOutDaysCount;

  void _showDayDetail(DateTime day) {
    final dateStr = _apiDateFmt.format(day);
    final soldOut = _soldOutOn(dateStr);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final textPrimary   = theme.colorScheme.onSurface;
        final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
        final rowBg          = isDark ? const Color(0xFF242424) : const Color(0xFFF7F8FA);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
              )),
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (soldOut.isEmpty ? _green : _darkRed).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    soldOut.isEmpty ? Icons.check_circle_outline : Icons.do_not_disturb_on_outlined,
                    color: soldOut.isEmpty ? _green : _darkRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_dayHeaderFmt.format(day), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    soldOut.isEmpty ? 'All hotels available' : '${soldOut.length} of ${_hotels.length} hotels sold out',
                    style: TextStyle(fontSize: 12, color: soldOut.isEmpty ? _green : _darkRed, fontWeight: FontWeight.w600),
                  ),
                ])),
              ]),
              if (soldOut.isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: soldOut.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final h = soldOut[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: rowBg,
                          borderRadius: BorderRadius.circular(10),
                          border: const Border(left: BorderSide(color: _darkRed, width: 3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h.hotelName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                            if (h.hotelCity.isNotEmpty)
                              Text(h.hotelCity, style: TextStyle(fontSize: 10.5, color: textSecondary)),
                          ])),
                          if (h.stars > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: _gold.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
                              child: Text('${h.stars}★', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _gold)),
                            ),
                        ]),
                      );
                    },
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg    = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          _buildHero(),
          Expanded(child: _buildBody(theme)),
        ]),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(6, 4, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sold-out Calendar', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${widget.stationCode} · ${widget.stationCity}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
        ]),

        const SizedBox(height: 12),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _monthNavButton(Icons.chevron_left, _month.isAfter(_minMonth) ? () => _changeMonth(-1) : null),
          Text(_monthFmt.format(_month), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          _monthNavButton(Icons.chevron_right, _month.isBefore(_maxMonth) ? () => _changeMonth(1) : null),
        ]),

        const SizedBox(height: 14),

        Row(children: [
          _heroStat(icon: Icons.do_not_disturb_on_outlined, label: 'Sold-out days', value: _loading ? '—' : '$_soldOutDaysCount',
              color: const Color(0xFFFF6B6B)),
          const SizedBox(width: 10),
          _heroStat(icon: Icons.check_circle_outline, label: 'Fully available', value: _loading ? '—' : '$_clearDaysCount',
              color: const Color(0xFF6FCF97)),
          const SizedBox(width: 10),
          _heroStat(icon: Icons.apartment_outlined, label: 'Hotels tracked', value: _loading ? '—' : '${_hotels.length}',
              color: Colors.white),
        ]),
      ]),
    );
  }

  Widget _monthNavButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(enabled ? 0.12 : 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: enabled ? Colors.white : Colors.white30, size: 20),
      ),
    );
  }

  Widget _heroStat({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ));
  }

  Widget _buildBody(ThemeData theme) {
    final isDark        = theme.brightness == Brightness.dark;
    final cardBg        = theme.cardColor;
    final textPrimary   = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor   = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, color: textSecondary, size: 40),
          const SizedBox(height: 12),
          Text('Could not load calendar data', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: _loadMonth,
            child: const Text('Retry'),
          ),
        ]),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(children: [
            Row(
              children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                  .map((d) => Expanded(child: Center(child: Text(
                d,
                style: GoogleFonts.robotoMono(fontSize: 9, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.4),
              ))))
                  .toList(),
            ),
            const SizedBox(height: 10),
            _buildGrid(borderColor, textPrimary, textSecondary),
          ]),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Wrap(spacing: 18, runSpacing: 8, children: [
            _legendChip(_darkRed, 'Hotel(s) sold out'),
            _legendChip(_green, 'Fully available'),
            _legendChip(borderColor, 'No data yet', outline: true),
          ]),
        ),

        const SizedBox(height: 14),

        Row(children: [
          Icon(Icons.info_outline, size: 14, color: textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(
            'Tap any date to see which hotels are sold out that day.',
            style: TextStyle(fontSize: 11, color: textSecondary),
          )),
        ]),
      ],
    );
  }

  Widget _buildGrid(Color borderColor, Color textPrimary, Color textSecondary) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1; // Monday = 1 -> 0 blanks

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final dateStr = _apiDateFmt.format(date);
      final hasData = _hasDataOn(dateStr);
      final soldOutCount = hasData ? _soldOutOn(dateStr).length : 0;
      final isToday = date.year == _today.year && date.month == _today.month && date.day == _today.day;

      final Color cellBg;
      final Color cellFg;
      if (!hasData) {
        cellBg = Colors.transparent;
        cellFg = textSecondary.withOpacity(0.6);
      } else if (soldOutCount > 0) {
        cellBg = _darkRed.withOpacity(0.13);
        cellFg = _darkRed;
      } else {
        cellBg = _green.withOpacity(0.11);
        cellFg = _green;
      }

      cells.add(Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasData ? () => _showDayDetail(date) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: cellBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isToday ? _gold : (hasData ? cellFg.withOpacity(0.35) : borderColor),
                  width: isToday ? 1.6 : 1,
                ),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$day', style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: hasData ? cellFg : textPrimary.withOpacity(0.55),
                )),
                const SizedBox(height: 3),
                if (soldOutCount > 0)
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(color: _darkRed.withOpacity(0.16), shape: BoxShape.circle),
                    child: Center(child: Text('$soldOutCount', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: _darkRed))),
                  )
                else if (hasData)
                  Container(width: 5, height: 5, decoration: BoxDecoration(color: _green.withOpacity(0.55), shape: BoxShape.circle))
                else
                  const SizedBox(height: 5),
              ]),
            ),
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      children: cells,
    );
  }

  Widget _legendChip(Color color, String label, {bool outline = false}) {
    final textSecondary = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 11, height: 11,
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: outline ? Border.all(color: color, width: 1.4) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500)),
    ]);
  }
}
