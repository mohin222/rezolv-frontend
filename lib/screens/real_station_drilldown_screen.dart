import 'package:flutter/material.dart';
import '../data/api_repository.dart';
import '../models/real_station.dart';
import '../models/real_hotel_days.dart';
import '../utils/error_messages.dart';
import '../widgets/custom_bottom_nav.dart';
import 'hotel_detail_screen.dart';
import 'sold_out_calendar_screen.dart';

class RealStationDrilldownScreen extends StatefulWidget {
  final RealStation station;
  final ValueChanged<int> onNavigateToTab;
  final String fromDate;
  final String toDate;

  const RealStationDrilldownScreen({
    super.key,
    required this.station,
    required this.onNavigateToTab,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<RealStationDrilldownScreen> createState() => _RealStationDrilldownScreenState();
}

class _RealStationDrilldownScreenState extends State<RealStationDrilldownScreen> {
  bool _loading = true;
  String? _error;
  List<String> _dates = [];
  List<String> _filteredDates = [];
  List<RealHotelDays> _hotels = [];

  static const _navy    = Color(0xFF0D2B4E);
  static const _gold    = Color(0xFFC1791C);
  static const _darkRed = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final (dates, hotels) = await ApiRepository().fetchStationDays(widget.station.code);
      if (!mounted) return;

      final from  = DateTime.parse(widget.fromDate);
      final to    = DateTime.parse(widget.toDate);
      final delta = to.difference(from).inDays + 1;
      final fDates = List.generate(delta, (i) {
        final d = from.add(Duration(days: i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      });

      setState(() {
        _dates         = dates;
        _filteredDates = fDates;
        _hotels        = hotels;
        _loading       = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  void _handleNavTap(BuildContext context, int index) {
    Navigator.of(context).pop();
    if (index != 0) widget.onNavigateToTab(index);
  }

  Map<int, List<RealHotelDays>> get _hotelsByStar {
    final map = <int, List<RealHotelDays>>{};
    for (final h in _hotels) map.putIfAbsent(h.stars, () => []).add(h);
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final bg          = theme.scaffoldBackgroundColor;
    final textPrimary = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: CustomBottomNav(selectedIndex: 0, onTap: (i) => _handleNavTap(context, i)),
      body: SafeArea(child: Column(children: [
              Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: _navy), onPressed: () => Navigator.of(context).pop()),
            Expanded(child: Text(widget.station.cityLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary))),
          ]),
        ),
        Expanded(child: _buildBody()),
      ])),
    );
  }

  Widget _buildBody() {
    final theme         = Theme.of(context);
    final isDark        = theme.brightness == Brightness.dark;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: textSecondary, size: 40),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
      ]));
    }

    final station    = widget.station;
    final starLevels = _hotelsByStar.keys.toList()..sort((a, b) => b.compareTo(a));

    final totalRoomsToday = _dates.isNotEmpty
        ? _hotels.fold<int>(0, (sum, h) => sum + (h.roomsFor(_dates[0]) ?? 0))
        : 0;

    final overallRooms = _filteredDates.fold<int>(0, (sum, d) =>
    sum + _hotels.fold<int>(0, (s, h) => s + (h.roomsFor(d) ?? 0)));

    final soldOutCount = _dates.isNotEmpty
        ? _hotels.where((h) => (h.roomsFor(_dates[0]) ?? 0) == 0).length
        : 0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: _navy,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(station.code, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(station.cityLabel.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
              ])),
              _statCol('$totalRoomsToday', 'ROOMS TODAY', Colors.white),
              const SizedBox(width: 16),
              _statCol('${_hotels.length}', 'HOTELS', Colors.white),
              const SizedBox(width: 16),
              _statCol('${station.gapRooms}', 'GAP ROOMS', const Color(0xFFFF6B6B)),
            ]),

            const SizedBox(height: 12),

            Row(children: [
              _statPill(icon: Icons.bed_outlined, label: 'Overall Rooms', value: '$overallRooms', color: Colors.white),
              const SizedBox(width: 10),
              _statPill(icon: Icons.do_not_disturb_on_outlined, label: 'Sold Out Today', value: '$soldOutCount',
                  color: soldOutCount > 0 ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50)),
            ]),

            const SizedBox(height: 16),

            Row(children: [5, 4, 3, 1].map((star) {
              final bucket  = station.starMix.where((s) => s.stars == star).firstOrNull;
              final rooms   = bucket?.rooms ?? 0;
              final htls    = bucket?.hotelCount ?? 0;
              final hasData = htls > 0;
              return Expanded(child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: hasData ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text(star == 1 ? 'Lounge' : '$star★',
                      style: TextStyle(color: hasData ? Colors.orange.shade300 : Colors.white30, fontSize: 9, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$rooms', style: TextStyle(color: hasData ? Colors.white : Colors.white30, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('$htls htls', style: TextStyle(color: hasData ? Colors.white54 : Colors.white24, fontSize: 8)),
                ]),
              ));
            }).toList()),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: _SoldOutCalendarBanner(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SoldOutCalendarScreen(
                stationCode: station.code,
                stationCity: station.cityLabel,
              ),
            )),
          ),
        ),

        const SizedBox(height: 12),

        for (final star in starLevels) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(children: [
              Container(width: 3, height: 13, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                star > 0
                    ? '${star == 1 ? 'Lounge' : '$star★'} HOTELS · ${_hotelsByStar[star]!.length} HOTELS'
                    : 'UNRATED · ${_hotelsByStar[star]!.length} HOTELS',
                style: TextStyle(fontSize: 11, color: textSecondary, letterSpacing: 0.5, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          ..._hotelsByStar[star]!.map((h) => _HotelDayRow(
            hotel: h, dates: _dates,
            locationCode: station.code, locationCity: station.cityLabel,
            onNavigateToTab: widget.onNavigateToTab, isDark: isDark,
          )),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _statCol(String value, String label, Color valueColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 0.6)),
    ]);
  }

  Widget _statPill({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    ));
  }
}

class _HotelDayRow extends StatelessWidget {
  final RealHotelDays hotel;
  final List<String> dates;
  final String locationCode, locationCity;
  final ValueChanged<int> onNavigateToTab;
  final bool isDark;

  const _HotelDayRow({
    required this.hotel, required this.dates,
    required this.locationCode, required this.locationCity,
    required this.onNavigateToTab, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme         = Theme.of(context);
    final cardBg        = theme.cardColor;
    final textPrimary   = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final todayRooms    = dates.isNotEmpty ? hotel.roomsFor(dates[0]) : null;
    final isSoldOut     = todayRooms == 0;

    return GestureDetector(
      onTap: () {
        final today = DateTime.now();
        final sevenDays = List.generate(7, (i) {
          final d = today.add(Duration(days: i));
          return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        });
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HotelDetailScreen(
            hotel: RealHotel(
              hotelId: hotel.hotelId, hotelName: hotel.hotelName,
              hotelCity: hotel.hotelCity, availableRooms: todayRooms ?? 0,
              anyStopsell: false,
              starCategory: hotel.stars > 0 ? '${hotel.stars}' : null,
              hotelSource: hotel.hotelSource,
              address: hotel.address, phone: hotel.phone, email: hotel.email,
            ),
            locationCode: locationCode, locationCity: locationCity,
            dates: sevenDays, dailySplit: hotel.dailySplit,
            onNavigateToTab: onNavigateToTab,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: isSoldOut ? const Border(left: BorderSide(color: Color(0xFFC62828), width: 4)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hotel.hotelName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary)),
                Text(hotel.hotelCity, style: TextStyle(fontSize: 11, color: textSecondary)),
              ])),
              if (hotel.stars > 0)
                Row(children: List.generate(hotel.stars, (_) => Icon(Icons.star, size: 10, color: Colors.orange.shade600))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _dayCell('Today',     dates.isNotEmpty ? hotel.roomsFor(dates[0]) : null)),
              const SizedBox(width: 6),
              Expanded(child: _dayCell('Tomorrow',  dates.length > 1 ? hotel.roomsFor(dates[1]) : null)),
              const SizedBox(width: 6),
              Expanded(child: _dayCell('Day After', dates.length > 2 ? hotel.roomsFor(dates[2]) : null)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _dayCell(String label, int? rooms) {
    final Color bg;
    final Color fg;
    if (rooms == null)   { bg = const Color(0xFF2A2A2A); fg = Colors.grey; }
    else if (rooms == 0) { bg = const Color(0xFFFAD9D9); fg = const Color(0xFFC62828); }
    else                 { bg = const Color(0xFFDFF3E3); fg = const Color(0xFF1B7A3D); }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(rooms?.toString() ?? '?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: fg)),
      ]),
    );
  }
}

class _SoldOutCalendarBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SoldOutCalendarBanner({required this.onTap});

  static const _navy    = Color(0xFF0D2B4E);
  static const _darkRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final theme          = Theme.of(context);
    final isDark         = theme.brightness == Brightness.dark;
    final cardBg         = theme.cardColor;
    final textPrimary    = theme.colorScheme.onSurface;
    final textSecondary  = theme.colorScheme.onSurface.withOpacity(0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _darkRed.withOpacity(0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _darkRed.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.event_busy_rounded, color: _darkRed, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sold-Out Calendar', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 2),
              Text('See every sold-out date this month', style: TextStyle(fontSize: 11, color: textSecondary)),
            ])),
            Icon(Icons.chevron_right, color: _navy, size: 20),
          ]),
        ),
      ),
    );
  }
}