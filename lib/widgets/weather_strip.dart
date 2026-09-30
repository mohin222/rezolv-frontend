import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_repository.dart';

/// Live current conditions + short forecast for one station, from the same
/// Lumo API key already used for Flights at Risk. Silently hides itself if
/// weather isn't available for a station — never blocks the rest of the
/// screen over a missing forecast.
class WeatherStrip extends StatefulWidget {
  final String stationCode;
  const WeatherStrip({super.key, required this.stationCode});

  @override
  State<WeatherStrip> createState() => _WeatherStripState();
}

class _WeatherStripState extends State<WeatherStrip> {
  static const _navy = Color(0xFF0D2B4E);
  static const _gold = Color(0xFFC1791C);

  static const _refreshInterval = Duration(seconds: 60);

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _showTomorrow = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await ApiRepository().fetchStationWeather(widget.stationCode);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  IconData _conditionIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunderstorm')) return Icons.bolt_rounded;
    if (c.contains('rain') || c.contains('drizzle')) return Icons.water_drop_rounded;
    if (c.contains('snow')) return Icons.ac_unit_rounded;
    if (c.contains('fog') || c.contains('mist') || c.contains('haze') || c.contains('smoke')) {
      return Icons.cloud_rounded;
    }
    return Icons.wb_sunny_rounded;
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'VFR':
        return const Color(0xFF2E7D32);
      case 'MVFR':
        return _gold;
      case 'IFR':
        return const Color(0xFFEF6C00);
      case 'LIFR':
        return const Color(0xFFC62828);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);

    if (_loading) {
      return Container(
        height: 64,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final current = (_data?['current'] as Map?)?.cast<String, dynamic>();
    if (current == null) return const SizedBox.shrink();

    final tempC = current['temp_c'];
    final condition = (current['condition'] as String?) ?? 'Clear';
    final wind = current['wind'] as String?;
    final visibility = current['visibility_mi'];
    final category = current['flight_category'] as String?;
    final categoryLabel = current['flight_category_label'] as String?;
    final forecastSummary = _data?['forecast_summary'] as String?;
    final showForecast = forecastSummary != null && !forecastSummary.startsWith('No significant');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.wb_cloudy_rounded, size: 13, color: textSecondary),
          const SizedBox(width: 6),
          _toggleTab('TODAY', !_showTomorrow, () => setState(() => _showTomorrow = false), textSecondary),
          const SizedBox(width: 2),
          _toggleTab('TOMORROW', _showTomorrow, () => setState(() => _showTomorrow = true), textSecondary),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showInfoSheet(context, cardBg, textPrimary, textSecondary),
            child: Icon(Icons.info_outline_rounded, size: 15, color: _gold),
          ),
        ]),
        const SizedBox(height: 10),
        if (!_showTomorrow) ...[
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Icon(_conditionIcon(condition), size: 19, color: _navy)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(tempC != null ? '$tempC°C' : '—',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(condition,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: textSecondary)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  [
                    if (wind != null) 'Wind $wind',
                    if (visibility != null) 'Vis ${visibility}mi',
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                ),
              ]),
            ),
            if (categoryLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _categoryColor(category).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(categoryLabel,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _categoryColor(category))),
              ),
          ]),
          if (showForecast) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: borderColor),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.schedule_rounded, size: 13, color: _gold),
              const SizedBox(width: 6),
              Expanded(child: Text(forecastSummary, style: TextStyle(fontSize: 11, color: textSecondary, height: 1.3))),
            ]),
          ],
        ] else
          _tomorrowContent(textPrimary, textSecondary),
      ]),
    );
  }

  Widget _toggleTab(String label, bool selected, VoidCallback onTap, Color textSecondary) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? _gold.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w700, color: selected ? _gold : textSecondary, letterSpacing: 0.4)),
      ),
    );
  }

  Widget _tomorrowContent(Color textPrimary, Color textSecondary) {
    final tomorrow = (_data?['tomorrow'] as Map?)?.cast<String, dynamic>();
    final available = tomorrow?['available'] == true;
    final summary = tomorrow?['summary'] as String?;

    if (!available) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.schedule_outlined, size: 16, color: textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tomorrow\'s forecast isn\'t published yet for this station — check closer to the time.',
            style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.4),
          ),
        ),
      ]);
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Icon(Icons.event_rounded, size: 18, color: _navy)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          summary ?? 'No significant weather expected tomorrow.',
          style: TextStyle(fontSize: 12.5, color: textPrimary, height: 1.4),
        ),
      ),
    ]);
  }

  void _showInfoSheet(BuildContext context, Color cardBg, Color textPrimary, Color textSecondary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).viewPadding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 18),
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _navy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.wb_cloudy_rounded, size: 18, color: _navy)),
            ),
            const SizedBox(width: 12),
            Text('Today\'s Weather', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          ]),
          const SizedBox(height: 18),
          _infoRow(Icons.thermostat_rounded, 'Temperature & condition', 'How hot/cold it is right now, and what\'s happening in the sky (rain, haze, smoke, clear).', textPrimary, textSecondary),
          const SizedBox(height: 14),
          _infoRow(Icons.air_rounded, 'Wind & visibility', 'How strong the wind is, and how far a pilot can see. Low visibility (fog/smoke/haze) is a major cause of flight delays.', textPrimary, textSecondary),
          const SizedBox(height: 14),
          _infoRow(Icons.verified_rounded, 'The colored badge', 'One-word safety summary — Good, Fair, Poor or Very Poor visibility for flying, right now.', textPrimary, textSecondary),
          const SizedBox(height: 14),
          _infoRow(Icons.schedule_rounded, 'Forecast line', 'Warns if worse weather is coming in the next few hours, and roughly when — so you know in advance if delays are likely.', textPrimary, textSecondary),
          const SizedBox(height: 14),
          _infoRow(Icons.source_outlined, 'Source & updates', 'Live from the same flight-data provider as Flights at Risk. Always today\'s real conditions — refreshes automatically every 30 minutes.', textPrimary, textSecondary),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: _navy, padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String body, Color textPrimary, Color textSecondary) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 2),
        Text(body, style: TextStyle(fontSize: 11.5, height: 1.4, color: textSecondary)),
      ])),
    ]);
  }
}
