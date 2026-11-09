import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/peak_date.dart';
import '../models/room_block.dart';
import '../widgets/peak_date_sheet.dart' show dateRange, peakWhen;

/// One station's peak dates and the rooms held at hotels for them — opened
/// from the station card chip and the Peak & Block Dates list.
class StationPeakScreen extends StatelessWidget {
  final String stationCode;
  final String stationCity;
  final List<PeakDate> peaks;
  final List<RoomBlock> blocks;

  const StationPeakScreen({
    super.key,
    required this.stationCode,
    required this.stationCity,
    required this.peaks,
    required this.blocks,
  });

  static const _navy = Color(0xFF0D2B4E);
  static final _fullFmt = DateFormat('d MMM yyyy');
  static final _dayFmt = DateFormat('d MMM');
  static final _numFmt = NumberFormat.decimalPattern('en_IN');

  static const _gold = Color(0xFFC1791C);
  static const _sections = [
    (type: 'hard', title: 'Hard blocks', subtitle: 'Confirmed with the hotel', icon: Icons.verified_rounded),
    (type: 'soft', title: 'Soft blocks', subtitle: 'Tentative, not yet confirmed', icon: Icons.schedule_rounded),
    (type: 'arranged', title: 'Peak-date arrangements', subtitle: 'Rooms arranged for the peak', icon: Icons.event_available_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final border = isDark ? Colors.grey.shade800 : const Color(0xFFE6E8EC);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          _hero(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                for (final p in peaks) ...[
                  _peakCard(p, theme.cardColor, border, textPrimary, textSecondary),
                  const SizedBox(height: 12),
                ],
                for (final s in _sections)
                  if (blocks.any((b) => b.type == s.type)) ...[
                    _blockSection(s.title, s.subtitle, s.icon, blocks.where((b) => b.type == s.type).toList(),
                        theme.cardColor, border, textPrimary, textSecondary),
                    const SizedBox(height: 12),
                  ],
                if (peaks.isEmpty && blocks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(child: Text('Nothing planned for this station.', style: TextStyle(color: textSecondary))),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    // Most rooms held on any one day (blocks overlap by date, so not a plain sum).
    var total = 0;
    for (final day in {for (final b in blocks) for (var d = b.start; !d.isAfter(b.end); d = d.add(const Duration(days: 1))) d}) {
      final t = blocks.where((b) => b.covers(day)).fold<int>(0, (s, b) => s + (b.roomsPerDay ?? 0));
      if (t > total) total = t;
    }
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(6, 4, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Peak dates & room blocks', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(stationCity.isEmpty ? stationCode : '$stationCode · $stationCity', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(children: [
            _stat(Icons.local_fire_department_rounded, const Color(0xFFFF8A65), '${peaks.length}', peaks.length == 1 ? 'Peak period' : 'Peak periods'),
            const SizedBox(width: 10),
            _stat(Icons.apartment_rounded, const Color(0xFF90CAF9), '${blocks.map((b) => b.hotelName).toSet().length}', 'Hotels'),
            const SizedBox(width: 10),
            _stat(Icons.king_bed_rounded, const Color(0xFFA5D6A7), total == 0 ? '—' : '$total', 'Rooms held / day'),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
          ]),
        ),
      );

  Widget _card(Color bg, Color border, Widget child) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  /// Tinted header band shared by every card: icon in a soft circle, title,
  /// subtitle and a trailing widget — the one place each card shows colour.
  Widget _header(Color color, IconData icon, String title, String subtitle, Widget trailing, Color textPrimary, Color textSecondary) =>
      Container(
        color: color.withOpacity(0.08),
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.16), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary)),
            if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 11, color: textSecondary)),
          ])),
          trailing,
        ]),
      );

  Widget _pill(Color color, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _peakCard(PeakDate p, Color bg, Color border, Color textPrimary, Color textSecondary) {
    Widget line(IconData icon, String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 15, color: textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.3, color: color ?? textPrimary))),
          ]),
        );
    return _card(bg, border, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(p.color, p.isBlock ? Icons.block_rounded : Icons.local_fire_department_rounded, p.name, p.kindLabel,
          _pill(p.color, p.impactLabel), textPrimary, textSecondary),
      Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        line(Icons.event_outlined, '${_fullFmt.format(p.start)}${p.start == p.end ? '' : ' – ${_fullFmt.format(p.end)}'}  ·  ${peakWhen(p)}'),
        if (p.expectedVisitors != null) line(Icons.groups_outlined, '${_numFmt.format(p.expectedVisitors)} expected visitors'),
        if (p.tightestRooms != null && p.tightestDay != null)
          line(Icons.king_bed_outlined, 'Fewest rooms in RICH: ${_numFmt.format(p.tightestRooms)} on ${_dayFmt.format(p.tightestDay!)}',
              color: p.tightestRooms! < 200 ? const Color(0xFFC62828) : null),
        if (p.notes.isNotEmpty) line(Icons.notes_outlined, p.notes, color: textSecondary),
      ]),
    ),
    ]));
  }

  Widget _blockSection(String title, String subtitle, IconData icon, List<RoomBlock> rows, Color bg, Color border,
      Color textPrimary, Color textSecondary) {
    final color = rows.first.color;
    rows.sort((a, b) {
      final d = a.start.compareTo(b.start);
      return d != 0 ? d : a.hotelName.compareTo(b.hotelName);
    });
    return _card(bg, border, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(color, icon, title, subtitle, _pill(color, '${rows.length} ${rows.length == 1 ? 'hotel' : 'hotels'}'), textPrimary, textSecondary),
      for (var i = 0; i < rows.length; i++) ...[
        Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rows[i].hotelName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 2),
              const SizedBox(height: 2),
              Row(children: [
                if (rows[i].star != null) ...[
                  Text('${rows[i].star}★', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _gold)),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.calendar_today_rounded, size: 11, color: textSecondary),
                const SizedBox(width: 4),
                Text(dateRange(rows[i].start, rows[i].end), style: TextStyle(fontSize: 11.5, color: textSecondary)),
              ]),
              if (rows[i].notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(rows[i].notes, style: TextStyle(fontSize: 11.5, height: 1.3, color: textSecondary, fontStyle: FontStyle.italic)),
              ],
            ])),
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (rows[i].roomsPerDay == null ? textSecondary : color).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text(rows[i].roomsPerDay == null ? 'Pending' : '${rows[i].roomsPerDay}',
                    style: TextStyle(fontSize: rows[i].roomsPerDay == null ? 12 : 16, fontWeight: FontWeight.w800,
                        color: rows[i].roomsPerDay == null ? textSecondary : color)),
                if (rows[i].roomsPerDay != null) Text('rooms/day', style: TextStyle(fontSize: 9.5, color: textSecondary)),
              ]),
            ),
          ]),
        ),
      ],
    ]));
  }
}
