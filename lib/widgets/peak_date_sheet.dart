import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/peak_date.dart';
import '../models/room_block.dart';

final _dayFmt = DateFormat('d MMM');
final _fullFmt = DateFormat('d MMM yyyy');
final _numFmt = NumberFormat.decimalPattern('en_IN');

/// "19–22 Nov" / "30 Nov – 2 Dec" / "22 Nov" for one day.
String peakRange(PeakDate p) => dateRange(p.start, p.end);

String dateRange(DateTime start, DateTime end) {
  if (start == end) return _dayFmt.format(start);
  if (start.month == end.month) return '${start.day}–${_dayFmt.format(end)}';
  return '${_dayFmt.format(start)} – ${_dayFmt.format(end)}';
}

String peakWhen(PeakDate p) {
  if (p.ongoing) return 'On now';
  if (p.daysToGo == 0) return 'Today';
  if (p.daysToGo == 1) return 'Tomorrow';
  return 'In ${p.daysToGo} days';
}

/// Bottom sheet with the details of peak / block dates and the rooms held
/// at hotels for them.
void showPeakDatesSheet(BuildContext context, List<PeakDate> peaks, {String? title, List<RoomBlock> blocks = const []}) {
  final theme = Theme.of(context);
  final textPrimary = theme.colorScheme.onSurface;
  final textSecondary = theme.colorScheme.onSurface.withOpacity(0.6);

  showModalBottomSheet(
    context: context,
    backgroundColor: theme.cardColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            if (title != null) ...[
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 12),
            ],
            for (final p in peaks) PeakDetailCard(peak: p, textPrimary: textPrimary, textSecondary: textSecondary),
            if (blocks.isNotEmpty) RoomBlocksSection(blocks: blocks, textPrimary: textPrimary, textSecondary: textSecondary),
          ],
        ),
      ),
    ),
  );
}

class PeakDetailCard extends StatelessWidget {
  final PeakDate peak;
  final Color textPrimary, textSecondary;
  const PeakDetailCard({required this.peak, required this.textPrimary, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    final p = peak;
    final where = p.allStations ? 'All stations' : (p.stationCity.isNotEmpty ? '${p.station} · ${p.stationCity}' : p.station);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textSecondary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary))),
          Container(width: 7, height: 7, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(p.impactLabel, style: TextStyle(fontSize: 11, color: textSecondary)),
        ]),
        const SizedBox(height: 6),
        Text('$where · ${p.kindLabel}', style: TextStyle(fontSize: 12, color: textSecondary)),
        const SizedBox(height: 10),
        _line(Icons.event_rounded, '${_fullFmt.format(p.start)}${p.start == p.end ? '' : ' – ${_fullFmt.format(p.end)}'}  ·  ${peakWhen(p)}'),
        if (p.expectedVisitors != null) _line(Icons.groups_rounded, '${_numFmt.format(p.expectedVisitors)} expected visitors'),
        if (p.hotelName.isNotEmpty) _line(Icons.hotel_rounded, p.hotelName),
        if (p.tightestRooms != null && p.tightestDay != null)
          _line(Icons.king_bed_rounded, 'Fewest rooms: ${_numFmt.format(p.tightestRooms)} on ${_dayFmt.format(p.tightestDay!)} (live)',
              color: p.tightestRooms! < 200 ? const Color(0xFFC62828) : null),
        if (p.notes.isNotEmpty) _line(Icons.notes_rounded, p.notes),
      ]),
    );
  }

  Widget _line(IconData icon, String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color ?? textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.3, color: color ?? textPrimary, fontWeight: color != null ? FontWeight.w600 : FontWeight.normal))),
        ]),
      );
}

/// Hard → soft → arranged, then by date and hotel.
List<RoomBlock> sortedBlocks(Iterable<RoomBlock> blocks) {
  const order = {'hard': 0, 'soft': 1, 'arranged': 2};
  return blocks.toList()
    ..sort((a, b) {
      final t = (order[a.type] ?? 3).compareTo(order[b.type] ?? 3);
      if (t != 0) return t;
      final d = a.start.compareTo(b.start);
      return d != 0 ? d : a.hotelName.compareTo(b.hotelName);
    });
}

/// "Rooms held at hotels" — one row per block, with optional per-type totals
/// for a single [day].
class RoomBlocksSection extends StatelessWidget {
  final List<RoomBlock> blocks;
  final Color textPrimary, textSecondary;
  final DateTime? day;
  const RoomBlocksSection({super.key, required this.blocks, required this.textPrimary, required this.textSecondary, this.day});

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    if (day != null) {
      for (final b in blocks) {
        totals[b.typeLabel] = (totals[b.typeLabel] ?? 0) + (b.roomsPerDay ?? 0);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 4),
      Text('ROOMS HELD AT HOTELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: textSecondary)),
      if (totals.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in totals.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: textSecondary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('${e.key}: ${e.value} rooms', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
            ),
        ]),
      ],
      const SizedBox(height: 8),
      for (final b in sortedBlocks(blocks)) RoomBlockTile(block: b, textPrimary: textPrimary, textSecondary: textSecondary, showDates: day == null),
    ]);
  }
}

class RoomBlockTile extends StatelessWidget {
  final RoomBlock block;
  final Color textPrimary, textSecondary;
  final bool showDates;
  final bool showStation;
  const RoomBlockTile({super.key, required this.block, required this.textPrimary, required this.textSecondary,
      this.showDates = true, this.showStation = false});

  @override
  Widget build(BuildContext context) {
    final b = block;
    final sub = [
      if (showStation) b.station,
      if (b.star != null) '${b.star}★',
      if (showDates) dateRange(b.start, b.end),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textSecondary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.hotelName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 11.5, color: textSecondary)),
            ],
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(b.roomsLabel, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: b.roomsPerDay == null ? textSecondary : textPrimary)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: b.color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(b.typeLabel, style: TextStyle(fontSize: 10.5, color: textSecondary)),
            ]),
          ]),
        ]),
        if (b.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(b.notes, style: TextStyle(fontSize: 11.5, height: 1.3, color: textSecondary)),
        ],
      ]),
    );
  }
}
