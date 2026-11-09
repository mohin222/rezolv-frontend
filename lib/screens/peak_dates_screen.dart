import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/api_repository.dart';
import '../models/peak_date.dart';
import '../models/room_block.dart';
import '../utils/error_messages.dart';
import '../widgets/peak_date_sheet.dart';
import 'station_peak_screen.dart';

/// Every upcoming peak date and room block (next 12 months), grouped by
/// month, with station and type filters. Entered in the backend admin.
class PeakDatesScreen extends StatefulWidget {
  const PeakDatesScreen({super.key});

  @override
  State<PeakDatesScreen> createState() => _PeakDatesScreenState();
}

enum _TypeFilter { all, peaks, rooms }

class _PeakDatesScreenState extends State<PeakDatesScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);
  static final _monthFmt = DateFormat('MMMM yyyy');

  bool _loading = true;
  String? _error;
  List<PeakDate> _items = [];
  List<RoomBlock> _blocks = [];
  String _station = 'ALL'; // 'ALL' = every station
  _TypeFilter _type = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _items.isEmpty && _blocks.isEmpty; _error = null; });
    try {
      final results = await Future.wait([
        ApiRepository().fetchPeakDates(),
        ApiRepository().fetchRoomBlocks(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<PeakDate>;
        _blocks = results[1] as List<RoomBlock>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  /// Stations that have at least one date, for the filter chips.
  List<String> get _stations {
    return {
      ..._items.where((p) => !p.allStations).map((p) => p.station),
      ..._blocks.map((b) => b.station),
    }.toList()..sort();
  }

  /// Peaks and room blocks matching the filters, by start date — each item
  /// is a PeakDate or a RoomBlock.
  List<({DateTime start, bool ongoing, Object item})> get _filtered {
    final out = <({DateTime start, bool ongoing, Object item})>[
      if (_type != _TypeFilter.rooms)
        for (final p in _items)
          if (_station == 'ALL' || p.appliesTo(_station)) (start: p.start, ongoing: p.ongoing, item: p),
      if (_type != _TypeFilter.peaks)
        for (final b in sortedBlocks(_blocks))
          if (_station == 'ALL' || b.station == _station) (start: b.start, ongoing: b.ongoing, item: b),
    ];
    // Stable by start date: within a day, peaks first, then hard → soft → arranged.
    final indexed = out.asMap().entries.toList()
      ..sort((a, b) {
        final c = a.value.start.compareTo(b.value.start);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          _buildHero(),
          Expanded(child: _buildBody(theme)),
        ]),
      ),
    );
  }

  Widget _buildHero() {
    final peaks = _items.length;
    final blocks = _blocks.length;
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(6, 4, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Peak & Block Dates', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Next 12 months · all stations', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(children: [
            _heroStat(Icons.local_fire_department_rounded, 'Peak dates', _loading ? '—' : '$peaks', const Color(0xFFFF8A65)),
            const SizedBox(width: 10),
            _heroStat(Icons.hotel_rounded, 'Room blocks', _loading ? '—' : '$blocks', const Color(0xFF90CAF9)),
          ]),
        ),
      ]),
    );
  }

  Widget _heroStat(IconData icon, String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ));
  }

  Widget _buildBody(ThemeData theme) {
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, color: textSecondary, size: 40),
          const SizedBox(height: 12),
          Text('Could not load peak dates', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ]),
      ));
    }

    final items = _filtered;
    final children = <Widget>[_buildFilters(textSecondary), const SizedBox(height: 8)];

    if (items.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(children: [
          Icon(Icons.event_available_rounded, size: 40, color: textSecondary),
          const SizedBox(height: 10),
          Text('Nothing here yet', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 4),
          Text('Nothing entered for this filter yet.', style: TextStyle(fontSize: 12, color: textSecondary)),
        ]),
      ));
    } else {
      String? lastMonth;
      for (final e in items) {
        // Ongoing items sit under the current month.
        final month = _monthFmt.format(e.ongoing ? DateTime.now() : e.start);
        if (month != lastMonth) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(month.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: textSecondary)),
          ));
          lastMonth = month;
        }
        final item = e.item;
        children.add(item is PeakDate
            ? _PeakRow(
                peak: item,
                onTap: () => item.allStations
                    ? showPeakDatesSheet(context, [item])
                    : _openStation(item.station, item.stationCity),
                // Rooms held at that station during the peak.
                blocks: item.allStations
                    ? const []
                    : _blocks.where((b) => b.station == item.station && !b.start.isAfter(item.end) && !b.end.isBefore(item.start)).toList(),
                textPrimary: textPrimary,
                textSecondary: textSecondary)
            : _blockRow(item as RoomBlock, textPrimary, textSecondary));
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: children,
      ),
    );
  }

  Widget _blockRow(RoomBlock b, Color textPrimary, Color textSecondary) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openStation(b.station, b.stationCity),
        child: RoomBlockTile(block: b, showStation: true, textPrimary: textPrimary, textSecondary: textSecondary),
      );

  void _openStation(String code, String city) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StationPeakScreen(
        stationCode: code,
        stationCity: city,
        peaks: _items.where((p) => p.appliesTo(code)).toList(),
        blocks: _blocks.where((b) => b.station == code).toList(),
      ),
    ));
  }

  Widget _buildFilters(Color textSecondary) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onTap(),
            selectedColor: _gold.withOpacity(0.18),
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? _gold : textSecondary),
            side: BorderSide(color: selected ? _gold : textSecondary.withOpacity(0.3)),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip('All stations', _station == 'ALL', () => setState(() => _station = 'ALL')),
          for (final code in _stations) chip(code, _station == code, () => setState(() => _station = code)),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        chip('All', _type == _TypeFilter.all, () => setState(() => _type = _TypeFilter.all)),
        chip('Peaks', _type == _TypeFilter.peaks, () => setState(() => _type = _TypeFilter.peaks)),
        chip('Room blocks', _type == _TypeFilter.rooms, () => setState(() => _type = _TypeFilter.rooms)),
      ]),
    ]);
  }
}

class _PeakRow extends StatelessWidget {
  final PeakDate peak;
  final List<RoomBlock> blocks;
  final VoidCallback onTap;
  final Color textPrimary, textSecondary;
  const _PeakRow({required this.peak, required this.blocks, required this.onTap, required this.textPrimary, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    final p = peak;
    final where = p.allStations ? 'All stations' : p.station;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 2),
                Text('$where · ${peakRange(p)} · ${p.kindLabel}${blocks.isEmpty ? '' : ' · ${blocks.length} hotels'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: textSecondary)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(peakWhen(p), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(height: 2),
                Text(p.impactLabel, style: TextStyle(fontSize: 10, color: textSecondary)),
              ]),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: textSecondary),
            ]),
          ),
        ),
      ),
    );
  }
}
