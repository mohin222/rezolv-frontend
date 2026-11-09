import 'package:flutter/material.dart';

/// Rooms held at a hotel for a date range — hard block (confirmed), soft
/// block (tentative) or peak-date arrangement. Entered in the backend
/// admin (RoomBlock).
class RoomBlock {
  final int id;
  final String station;
  final String stationCity;
  final String hotelName;
  final int? star;
  final String type; // hard / soft / arranged
  final DateTime start;
  final DateTime end;
  final int? roomsPerDay; // null = allocation pending
  final String notes;
  final int daysToGo;
  final bool ongoing;

  const RoomBlock({
    required this.id,
    required this.station,
    required this.stationCity,
    required this.hotelName,
    required this.star,
    required this.type,
    required this.start,
    required this.end,
    required this.roomsPerDay,
    required this.notes,
    required this.daysToGo,
    required this.ongoing,
  });

  factory RoomBlock.fromJson(Map<String, dynamic> json) => RoomBlock(
        id: json['id'] as int,
        station: json['station'] as String? ?? '',
        stationCity: json['station_city'] as String? ?? '',
        hotelName: json['hotel_name'] as String? ?? '',
        star: (json['star'] as num?)?.toInt(),
        type: json['block_type'] as String? ?? 'hard',
        start: DateTime.parse(json['start_date'] as String),
        end: DateTime.parse(json['end_date'] as String),
        roomsPerDay: (json['rooms_per_day'] as num?)?.toInt(),
        notes: json['notes'] as String? ?? '',
        daysToGo: (json['days_to_go'] as num?)?.toInt() ?? 0,
        ongoing: json['ongoing'] == true,
      );

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String get typeLabel => switch (type) {
        'hard' => 'Hard block',
        'soft' => 'Soft block',
        _ => 'Arranged',
      };

  /// Hard = confirmed (green), soft = tentative (amber), arranged = blue.
  Color get color => switch (type) {
        'hard' => const Color(0xFF2E7D32),
        'soft' => const Color(0xFFB7791F),
        _ => const Color(0xFF1565C0),
      };

  String get roomsLabel => roomsPerDay == null ? 'Pending' : '$roomsPerDay rooms/day';
}

