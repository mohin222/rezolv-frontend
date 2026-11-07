import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/peak_date.dart';

final _dayFmt = DateFormat('d MMM');
final _fullFmt = DateFormat('d MMM yyyy');
final _numFmt = NumberFormat.decimalPattern('en_IN');

/// "19–22 Nov" / "30 Nov – 2 Dec" / "22 Nov" for one day.
String peakRange(PeakDate p) {
  if (p.start == p.end) return _dayFmt.format(p.start);
  if (p.start.month == p.end.month) return '${p.start.day}–${_dayFmt.format(p.end)}';
  return '${_dayFmt.format(p.start)} – ${_dayFmt.format(p.end)}';
}

String peakWhen(PeakDate p) {
  if (p.ongoing) return 'On now';
  if (p.daysToGo == 0) return 'Today';
  if (p.daysToGo == 1) return 'Tomorrow';
  return 'In ${p.daysToGo} days';
}

/// Bottom sheet with the details of one or more peak / block dates.
void showPeakDatesSheet(BuildContext context, List<PeakDate> peaks, {String? title}) {
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
        color: p.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: p.color, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: p.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(p.impactLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.color)),
          ),
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
