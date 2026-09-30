import 'package:flutter/material.dart';

/// Picks a weather icon from Lumo's decoded `condition` (active phenomena
/// like rain/fog/haze) and `sky` (cloud cover) fields together — using
/// `condition` alone misses plain cloudy weather, since "Clear" is what
/// the backend reports whenever there's no active rain/fog/etc., even if
/// the sky itself is overcast.
IconData weatherConditionIcon(String condition, [String? sky]) {
  final c = condition.toLowerCase();
  if (c.contains('thunderstorm')) return Icons.bolt_rounded;
  if (c.contains('rain') || c.contains('drizzle')) return Icons.water_drop_rounded;
  if (c.contains('snow')) return Icons.ac_unit_rounded;
  if (c.contains('fog') || c.contains('mist') || c.contains('haze') || c.contains('smoke')) {
    return Icons.cloud_rounded;
  }
  final s = (sky ?? '').toLowerCase();
  if (s.contains('overcast') || s.contains('broken')) return Icons.cloud_rounded;
  if (s.contains('scattered') || s.contains('few')) return Icons.wb_cloudy_rounded;
  return Icons.wb_sunny_rounded;
}
