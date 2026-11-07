import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/api_repository.dart';
import '../models/peak_date.dart';
import '../utils/error_messages.dart';
import '../widgets/peak_date_sheet.dart';

/// Every upcoming peak & block date (next 12 months), grouped by month,
/// with station and type filters. Entered by hand in the backend admin.
class PeakDatesScreen extends StatefulWidget {
  const PeakDatesScreen({super.key});

  @override
  State<PeakDatesScreen> createState() => _PeakDatesScreenState();
}

enum _TypeFilter { all, peaks, blocks }

class _PeakDatesScreenState extends State<PeakDatesScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);
  static final _monthFmt = DateFormat('MMMM yyyy');

  bool _loading = true;
  String? _error;
  List<PeakDate> _items = [];
  String _station = 'ALL'; // 'ALL' = every station
  _TypeFilter _type = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _items.isEmpty; _error = null; });
    try {
      final items = await ApiRepository().fetchPeakDates();
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  /// Stations that have at least one date, for the filter chips.
  List<String> get _stations {
    final codes = _items.where((p) => !p.allStations).map((p) => p.station).toSet().toList()..sort();
    return codes;
  }

  List<PeakDate> get _filtered => _items.where((p) {
        if (_station != 'ALL' && !p.appliesTo(_station)) return false;
        if (_type == _TypeFilter.peaks && p.isBlock) return false;
        if (_type == _TypeFilter.blocks && !p.isBlock) return false;
        return true;
      }).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

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
    final peaks = _items.where((p) => !p.isBlock).length;
    final blocks = _items.where((p) => p.isBlock).length;
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
            _heroStat(Icons.local_fire_department_rounded, 'Peak events', _loading ? '—' : '$peaks', const Color(0xFFFF8A65)),
            const SizedBox(width: 10),
            _heroStat(Icons.block_rounded, 'Block dates', _loading ? '—' : '$blocks', Colors.white70),
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
          Text('No peak or block dates', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 4),
          Text('Nothing entered for this filter yet.', style: TextStyle(fontSize: 12, color: textSecondary)),
        ]),
      ));
    } else {
      String? lastMonth;
      for (final p in items) {
        // Ongoing events sit under the current month.
        final month = _monthFmt.format(p.ongoing ? DateTime.now() : p.start);
        if (month != lastMonth) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(month.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: textSecondary)),
          ));
          lastMonth = month;
        }
        children.add(_PeakRow(peak: p, textPrimary: textPrimary, textSecondary: textSecondary));
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
        chip('Blocks', _type == _TypeFilter.blocks, () => setState(() => _type = _TypeFilter.blocks)),
      ]),
    ]);
  }
}

class _PeakRow extends StatelessWidget {
  final PeakDate peak;
  final Color textPrimary, textSecondary;
  const _PeakRow({required this.peak, required this.textPrimary, required this.textSecondary});

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
          onTap: () => showPeakDatesSheet(context, [p]),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: p.color, width: 4))),
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            child: Row(children: [
              Icon(p.isBlock ? Icons.block_rounded : Icons.local_fire_department_rounded, size: 20, color: p.color),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 2),
                Text('$where · ${peakRange(p)} · ${p.kindLabel}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: textSecondary)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(peakWhen(p), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.ongoing ? p.color : textSecondary)),
                const SizedBox(height: 2),
                Text(p.impactLabel, style: TextStyle(fontSize: 10, color: p.color, fontWeight: FontWeight.w600)),
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
