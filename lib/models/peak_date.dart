import 'package:flutter/material.dart';

/// A peak (high-demand) or block date for a station — entered by hand in
/// the backend admin (PeakDate). station is 'ALL' for dates that apply to
/// every station, such as wedding dates.
class PeakDate {
  final int id;
  final String name;
  final String kind; // exhibition / wedding / festival / other / block
  final String kindLabel;
  final String impact; // high / medium / low
  final String station;
  final String stationCity;
  final DateTime start;
  final DateTime end;
  final int? expectedVisitors;
  final String hotelName;
  final String notes;
  final int daysToGo;
  final bool ongoing;
  final DateTime? tightestDay;
  final int? tightestRooms;

  const PeakDate({
    required this.id,
    required this.name,
    required this.kind,
    required this.kindLabel,
    required this.impact,
    required this.station,
    required this.stationCity,
    required this.start,
    required this.end,
    required this.expectedVisitors,
    required this.hotelName,
    required this.notes,
    required this.daysToGo,
    required this.ongoing,
    required this.tightestDay,
    required this.tightestRooms,
  });

  factory PeakDate.fromJson(Map<String, dynamic> json) {
    final low = (json['lowest_availability'] as Map?)?.cast<String, dynamic>();
    return PeakDate(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'other',
      kindLabel: json['kind_label'] as String? ?? '',
      impact: json['impact'] as String? ?? 'medium',
      station: json['station'] as String? ?? '',
      stationCity: json['station_city'] as String? ?? '',
      start: DateTime.parse(json['start_date'] as String),
      end: DateTime.parse(json['end_date'] as String),
      expectedVisitors: (json['expected_visitors'] as num?)?.toInt(),
      hotelName: json['hotel_name'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      daysToGo: (json['days_to_go'] as num?)?.toInt() ?? 0,
      ongoing: json['ongoing'] == true,
      tightestDay: low?['date'] != null ? DateTime.parse(low!['date'] as String) : null,
      tightestRooms: (low?['rooms'] as num?)?.toInt(),
    );
  }

  bool get isBlock => kind == 'block';
  bool get allStations => station == 'ALL';

  bool appliesTo(String stationCode) => allStations || station == stationCode;

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// One colour language everywhere: red = high-impact peak, orange =
  /// medium, amber-grey = low, grey = block dates.
  Color get color {
    if (isBlock) return const Color(0xFF6B7280);
    switch (impact) {
      case 'high':
        return const Color(0xFFC62828);
      case 'low':
        return const Color(0xFFB08A2E);
      default:
        return const Color(0xFFEF6C00);
    }
  }

  String get impactLabel => isBlock ? 'Block' : '${impact[0].toUpperCase()}${impact.substring(1)} impact';
}
