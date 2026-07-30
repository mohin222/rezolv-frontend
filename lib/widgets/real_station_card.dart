import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/real_station.dart';

class RealStationCard extends StatefulWidget {
  final RealStation station;
  const RealStationCard({super.key, required this.station});

  @override
  State<RealStationCard> createState() => _RealStationCardState();
}

class _RealStationCardState extends State<RealStationCard> {
  static const _gold    = Color(0xFFC1791C);
  static const _darkRed = Color(0xFFC62828);
  static const _navy    = Color(0xFF0D2B4E);

  int _starMixMode = 0; // 0=Both, 1=CM, 2=Manual

  Color get _gapColor => widget.station.gapRooms == 0 ? Colors.green : _darkRed;

  List<RealStarBucket> _computeStarMix(String sourceFilter) {
    final filtered = widget.station.hotels.where((h) {
      final src = (h.hotelSource ?? '').toLowerCase();
      if (sourceFilter == 'channel_manager') return src == 'channel_manager';
      return src == 'extranet';
    }).toList();
    final map = <int, _StarAcc>{};
    for (final h in filtered) {
      final star = _parseStar(h.starCategory);
      map.putIfAbsent(star, () => _StarAcc());
      map[star]!.rooms += h.availableRooms;
      map[star]!.hotels += 1;
    }
    return [5, 4, 3, 1].map((s) {
      final acc = map[s];
      return RealStarBucket(stars: s, rooms: acc?.rooms ?? 0, hotelCount: acc?.hotels ?? 0);
    }).toList();
  }

  int _parseStar(String? cat) {
    if (cat == null) return 3;
    final c = cat.trim();
    if (c.startsWith('5')) return 5;
    if (c.startsWith('4')) return 4;
    if (c.startsWith('3')) return 3;
    if (c.startsWith('1')) return 1;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final isDark      = theme.brightness == Brightness.dark;
    final cardBg      = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final dividerColor  = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final chipBg        = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7);
    final chipBgEmpty   = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9);

    final starBuckets = _starMixMode == 0
        ? [5, 4, 3, 1].map((star) {
      final b = widget.station.starMix.where((s) => s.stars == star).firstOrNull;
      return RealStarBucket(stars: star, rooms: b?.rooms ?? 0, hotelCount: b?.hotelCount ?? 0);
    }).toList()
        : _starMixMode == 1
        ? _computeStarMix('channel_manager')
        : _computeStarMix('extranet');

    final split = widget.station.cmManualSplit;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Station code + SO badge
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.station.code, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
            Text(widget.station.cityLabel, style: TextStyle(fontSize: 10.5, color: textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.station.soldOutCount > 0 ? const Color(0xFFFCE4E4) : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 6, color: widget.station.soldOutCount > 0 ? _darkRed : Colors.green),
              const SizedBox(width: 4),
              Text('${widget.station.soldOutCount} SO',
                  style: TextStyle(fontSize: 9.5, color: widget.station.soldOutCount > 0 ? _darkRed : Colors.black87)),
            ]),
          ),
        ]),

        const SizedBox(height: 10),

        // Gauge + Stats
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 56, height: 56,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 56, height: 56, child: CircularProgressIndicator(
                value: ((widget.station.fillPct + 1) / 100).clamp(0.0, 1.0),
                strokeWidth: 4.5,
                backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${widget.station.roomsToday}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                Text('ROOMS', style: TextStyle(fontSize: 6.5, color: textSecondary)),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [
            _statRow('Hotels',     '${widget.station.hotelCount}',                  textPrimary,  textSecondary),
            _statRow('Fill',       '${widget.station.fillPct.toStringAsFixed(1)}%', _darkRed,     textSecondary),
            _statRow('Gap',        '${widget.station.gapRooms}',                    _gapColor,    textSecondary),
            _statRow('Block util', widget.station.blockUtil ?? '0',                 _darkRed,     textSecondary),
          ])),
        ]),

        const SizedBox(height: 10),

        // CM/Manual bar
        _cmManualBar(isDark),
        const SizedBox(height: 6),

        // ── CM/Manual legend WITH toggle buttons inline ──────────
        Row(children: [
          // Left: ● [CM] 6 rooms
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          _toggleBtn('CM', 1, _navy),
          const SizedBox(width: 6),
          Text('${split.cmRooms} rooms', style: GoogleFonts.robotoMono(fontSize: 9.5, color: textSecondary)),

          const Spacer(),

          // Right: ● 0 rooms [Manual]
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('${split.manualRooms} rooms', style: GoogleFonts.robotoMono(fontSize: 9.5, color: textSecondary)),
          const SizedBox(width: 6),
          _toggleBtn('Manual', 2, _gold),
        ]),

        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: dividerColor)),

        // Star Mix label
        Text('STAR MIX', style: GoogleFonts.robotoMono(fontSize: 8.5, color: textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 6),

        // Star chips
        Row(children: starBuckets.map((b) => Expanded(child: _starChip(b, chipBg, chipBgEmpty, textPrimary, textSecondary))).toList()),

        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: dividerColor)),

        // Footer
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Live from RICH', style: TextStyle(fontSize: 9.5, color: textSecondary)),
          const Row(children: [
            Text('Drilldown', style: TextStyle(color: _gold, fontWeight: FontWeight.w600, fontSize: 10.5)),
            Icon(Icons.arrow_forward, size: 12, color: _gold),
          ]),
        ]),
      ]),
    );
  }

  Widget _toggleBtn(String label, int mode, Color color) {
    final active = _starMixMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _starMixMode = active ? 0 : mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: active ? Colors.white : color)),
          if (active) ...[const SizedBox(width: 3), const Icon(Icons.close, size: 8, color: Colors.white)],
        ]),
      ),
    );
  }

  Widget _cmManualBar(bool isDark) {
    final split = widget.station.cmManualSplit;
    final total = split.cmRooms + split.manualRooms;
    if (total == 0) {
      return ClipRRect(borderRadius: BorderRadius.circular(3), child: Container(height: 4, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(height: 4, child: Row(children: [
      if (split.cmRooms > 0) Expanded(flex: split.cmRooms, child: Container(color: _navy)),
      if (split.manualRooms > 0) Expanded(flex: split.manualRooms, child: Container(color: _gold)),
    ])));
  }

  Widget _statRow(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valueColor)),
      ]),
    );
  }

  Widget _starChip(RealStarBucket s, Color chipBg, Color chipBgEmpty, Color textPrimary, Color textSecondary) {
    final isEmpty = s.hotelCount == 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: isEmpty ? chipBgEmpty : chipBg, borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(s.stars == 1 ? 'Lounge' : '${s.stars}★', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: textSecondary)),
        const SizedBox(height: 2),
        Text('${s.rooms}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
        Text('rooms', style: TextStyle(fontSize: 7, color: textSecondary)),
        const SizedBox(height: 1),
        Text(isEmpty ? 'none' : '${s.hotelCount} htls', style: TextStyle(fontSize: 7.5, color: textSecondary)),
      ]),
    );
  }
}

class _StarAcc {
  int rooms = 0;
  int hotels = 0;
}