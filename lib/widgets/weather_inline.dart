import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_repository.dart';

/// Just the icon + temperature, no pill of its own — meant to sit inside
/// another chip (the "Tmr · Week" flight-risk pill) rather than as its own
/// separate element on the station card. Renders nothing while loading or
/// if weather isn't available, so it never leaves a gap in the parent chip.
class WeatherInline extends StatefulWidget {
  final String stationCode;
  final Color color;
  const WeatherInline({super.key, required this.stationCode, required this.color});

  @override
  State<WeatherInline> createState() => _WeatherInlineState();
}

class _WeatherInlineState extends State<WeatherInline> {
  static const _refreshInterval = Duration(seconds: 60);

  Map<String, dynamic>? _data;
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
    setState(() => _data = data);
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

  @override
  Widget build(BuildContext context) {
    final current = (_data?['current'] as Map?)?.cast<String, dynamic>();
    if (current == null) return const SizedBox.shrink();

    final tempC = current['temp_c'];
    final condition = (current['condition'] as String?) ?? 'Clear';

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 1, height: 10, color: widget.color.withOpacity(0.35), margin: const EdgeInsets.symmetric(horizontal: 6)),
      Icon(_conditionIcon(condition), size: 10, color: widget.color),
      const SizedBox(width: 3),
      Text(
        tempC != null ? '$tempC°C' : '—',
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: widget.color),
      ),
    ]);
  }
}
