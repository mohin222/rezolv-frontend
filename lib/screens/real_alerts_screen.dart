import 'package:flutter/material.dart';
import '../data/api_repository.dart';
import '../models/real_station.dart';
import '../utils/app_version.dart';
class RealAlertsScreen extends StatefulWidget {
  const RealAlertsScreen({super.key});
  @override
  State<RealAlertsScreen> createState() => _RealAlertsScreenState();
}

class _AlertHotelEntry {
  final String stationCode;
  final RealHotel hotel;
  final bool isSoldOut;
  final bool isStopsell;
  _AlertHotelEntry({required this.stationCode, required this.hotel, required this.isSoldOut, required this.isStopsell});
}

class _RealAlertsScreenState extends State<RealAlertsScreen> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  bool _loading = true;
  String? _error;
  List<_AlertHotelEntry> _alertEntries = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stations = await ApiRepository().fetchAllStations();
      final entries = <_AlertHotelEntry>[];
      for (final station in stations) {
        for (final hotel in station.hotels) {
          final isSoldOut = hotel.availableRooms == 0;
          final isStopsell = hotel.anyStopsell;
          if (isSoldOut || isStopsell) {
            entries.add(_AlertHotelEntry(stationCode: station.code, hotel: hotel, isSoldOut: isSoldOut, isStopsell: isStopsell));
          }
        }
      }
      setState(() { _alertEntries = entries; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(cardBg, textPrimary, textSecondary, isDark),
          if (!_loading && _error == null) _buildSummaryBar(cardBg, textPrimary, textSecondary, borderColor),
          Expanded(child: _buildBody(textPrimary, textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildHeader(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    return Container(
      color: cardBg,
      child: Column(children: [
                Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(9)),
              child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rezolv', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
              Text('Alerts · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),
            ])),
            IconButton(icon: const Icon(Icons.refresh, color: _navy, size: 20), onPressed: _loadAlerts, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSummaryBar(Color cardBg, Color textPrimary, Color textSecondary, Color borderColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: const Color(0xFFFCE4E4), borderRadius: BorderRadius.circular(9)),
          child: const Center(child: Icon(Icons.error_outline_rounded, size: 20, color: Color(0xFFC62828))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_alertEntries.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2B4E))),
          Text('hotels sold out or going dark', style: TextStyle(fontSize: 11.5, color: textSecondary)),
        ])),
      ]),
    );
  }

  Widget _buildBody(Color textPrimary, Color textSecondary) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _navy));
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: textSecondary, size: 40),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadAlerts, style: ElevatedButton.styleFrom(backgroundColor: _navy), child: const Text('Retry', style: TextStyle(color: Colors.white))),
      ])));
    }
    if (_alertEntries.isEmpty) {
      return RefreshIndicator(
        color: _navy, onRefresh: _loadAlerts,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          const SizedBox(height: 120),
          const Icon(Icons.check_circle_outline_rounded, size: 52, color: Colors.green),
          const SizedBox(height: 14),
          Center(child: Text('No sold-out alerts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary))),
          const SizedBox(height: 8),
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text('All hotels have available inventory right now.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4)))),
        ]),
      );
    }
    return RefreshIndicator(
      color: _navy, onRefresh: _loadAlerts,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: _alertEntries.length,
        itemBuilder: (context, index) => _AlertCard(entry: _alertEntries[index], navy: _navy),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final _AlertHotelEntry entry;
  final Color navy;
  const _AlertCard({required this.entry, required this.navy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: const BorderSide(color: Color(0xFFC62828), width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(entry.stationCode, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: navy)),
            const SizedBox(width: 6),
            Text('·', style: TextStyle(color: textSecondary)),
            const SizedBox(width: 6),
            Expanded(child: Text(entry.hotel.hotelCity, style: TextStyle(fontSize: 11.5, color: textSecondary), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(entry.hotel.hotelName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            if (entry.isSoldOut) _tag('Sold out', const Color(0xFFC62828)),
            if (entry.isStopsell) _tag('Stop Sell', Colors.orange.shade800),
          ]),
        ])),
      ]),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}